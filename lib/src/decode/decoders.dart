import '../options.dart';
import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string_utils.dart';
import 'parser.dart';
import 'scanners.dart';
import 'validation.dart';

JsonValue decodeValueFromLines(LineCursor cursor, DecodeOptions options) {
  final first = cursor.peek();
  if (first == null) {
    return <String, JsonValue>{};
  }
  if (first.depth != 0) {
    throw overIndentedLineError(first, 0);
  }
  final content = first.content;

  if (content == '[]') {
    cursor.advance();
    assertFullyConsumed(cursor);
    return <JsonValue>[];
  }

  if (isArrayHeaderContent(content)) {
    final headerInfo = _withLine(
      first,
      () => resolveArrayHeader(content, options.strict),
    );
    if (headerInfo != null) {
      cursor.advance();
      final array = decodeArrayFromHeader(
        headerInfo.header,
        headerInfo.inlineValues,
        cursor,
        0,
        options,
      );
      assertFullyConsumed(cursor);
      return array;
    }
  }

  if (cursor.length == 1 && !isKeyValueContent(content)) {
    return _withLine(first, () => parsePrimitiveToken(content));
  }

  return decodeObject(cursor, 0, options);
}

/// Parser helpers don't know their line; this prefixes it to their errors.
T _withLine<T>(ParsedLine line, T Function() parse) {
  try {
    return parse();
  } on FormatException catch (e) {
    throw FormatException('Line ${line.lineNumber}: ${e.message}');
  }
}

void assertNoDepthJump(ParsedLine nestedLine, int parentDepth, bool strict) {
  if (strict && nestedLine.depth > parentDepth + 1) {
    throw FormatException(
      'Line ${nestedLine.lineNumber}: Indentation depth jump: expected depth ${parentDepth + 1}, but found ${nestedLine.depth}',
    );
  }
}

FormatException overIndentedLineError(ParsedLine line, int contentDepth) {
  return FormatException(
    'Line ${line.lineNumber}: Over-indented line: expected depth $contentDepth, but found ${line.depth}',
  );
}

/// Returns the depth of a scope's content lines: one below [baseDepth], or in
/// non-strict mode the depth of a deeper first line.
int scopeContentDepth(LineCursor cursor, int baseDepth, bool strict) {
  final first = cursor.peek();
  if (first == null || first.depth <= baseDepth + 1) {
    return baseDepth + 1;
  }
  assertNoDepthJump(first, baseDepth, strict);
  return first.depth;
}

/// Decoding never silently discards input, so a line after the root form is
/// an error.
void assertFullyConsumed(LineCursor cursor) {
  final line = cursor.peek();
  if (line == null) return;
  throw FormatException(
    'Line ${line.lineNumber}: Unexpected content after the document root',
  );
}

JsonObject decodeObject(
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
) {
  final obj = <String, JsonValue>{};

  // The first field sets the depth, which non-strict mode lets sit deeper
  // than `baseDepth`.
  int? fieldDepth;

  while (!cursor.atEnd) {
    final line = cursor.peek()!;
    if (line.depth < baseDepth) {
      break;
    }

    fieldDepth ??= line.depth;
    if (line.depth != fieldDepth) {
      throw overIndentedLineError(line, fieldDepth);
    }

    cursor.advance();
    decodeField(line.content, cursor, fieldDepth, options, obj);
  }

  return obj;
}

/// Decodes the key-value line [content] and its nested lines into [obj].
void decodeField(
  String content,
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
  JsonObject obj,
) {
  final line = cursor.current!;
  if (_withLine(line, () => resolveArrayHeader(content, options.strict))
      case final result?) {
    final header = result.header;
    if (header.key case final key?) {
      _assertNewKey(obj, key, line, options.strict);
      obj[key] = decodeArrayFromHeader(
        header,
        result.inlineValues,
        cursor,
        baseDepth,
        options,
      );
      return;
    }
    throw FormatException(
      header.keyed
          ? 'Line ${line.lineNumber}: Keyless keyed header is only valid at the document root'
          : 'Line ${line.lineNumber}: Keyless array header is only valid at the document root or as a list item',
    );
  }

  final (:key, :end) = _withLine(line, () => parseKeyToken(content));
  final rest = trimSpaces(content.substring(end));
  _assertNewKey(obj, key, line, options.strict);

  if (rest.isEmpty) {
    final nextLine = cursor.peek();
    if (nextLine != null && nextLine.depth > baseDepth) {
      assertNoDepthJump(nextLine, baseDepth, options.strict);
      obj[key] = decodeObject(cursor, baseDepth + 1, options);
    } else {
      obj[key] = <String, JsonValue>{};
    }
    return;
  }

  obj[key] = rest == '[]'
      ? <JsonValue>[]
      : _withLine(line, () => parsePrimitiveToken(rest));
}

/// Strict mode rejects duplicate sibling keys; non-strict mode lets the last
/// write win.
void _assertNewKey(JsonObject obj, String key, ParsedLine line, bool strict) {
  if (strict && obj.containsKey(key)) {
    throw FormatException(
      'Line ${line.lineNumber}: Duplicate sibling key "$key"',
    );
  }
}

JsonValue decodeArrayFromHeader(
  ArrayHeaderInfo header,
  String? inlineValues,
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
) {
  if (header.keyed) {
    return decodeKeyedObject(header, cursor, baseDepth, options);
  }

  if (inlineValues != null) {
    return decodeInlinePrimitiveArray(
      header,
      inlineValues,
      cursor.current!,
      options,
    );
  }

  if (header.fields != null) {
    return decodeTabularArray(header, cursor, baseDepth, options);
  }

  return decodeListArray(header, cursor, baseDepth, options);
}

List<JsonPrimitive> decodeInlinePrimitiveArray(
  ArrayHeaderInfo header,
  String inlineValues,
  ParsedLine headerLine,
  DecodeOptions options,
) {
  final primitives = _withLine(
    headerLine,
    () => mapRowValuesToPrimitives(
      parseDelimitedValues(inlineValues, header.delimiter),
    ),
  );

  if (options.strict) {
    assertExpectedCount(
      primitives.length,
      header.length,
      'inline array items',
      headerLine,
    );
  }

  return primitives;
}

List<JsonValue> decodeListArray(
  ArrayHeaderInfo header,
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
) {
  final items = <JsonValue>[];
  final itemDepth = scopeContentDepth(cursor, baseDepth, options.strict);

  int? startLine;
  int? endLine;

  while (!cursor.atEnd) {
    final line = cursor.peek()!;
    if (line.depth <= baseDepth) {
      break;
    }

    if (line.depth != itemDepth) {
      throw overIndentedLineError(line, itemDepth);
    }

    final isListItem =
        line.content.startsWith(listItemPrefix) ||
        line.content == listItemMarker;
    if (!isListItem) {
      break;
    }

    startLine ??= line.lineNumber;
    items.add(decodeListItem(cursor, itemDepth, options));
    endLine = cursor.current!.lineNumber;
  }

  if (options.strict) {
    assertExpectedCount(
      items.length,
      header.length,
      'list array items',
      cursor.current!,
    );
    validateNoBlankLinesInRange(
      startLine,
      endLine,
      cursor.blankLines,
      'list array',
    );
  }

  return items;
}

List<JsonObject> decodeTabularArray(
  ArrayHeaderInfo header,
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
) {
  final objects = <JsonObject>[];
  final fields = header.fields!;
  final rowDepth = scopeContentDepth(cursor, baseDepth, options.strict);
  final leafCount = countLeafFields(fields);

  int? startLine;
  int? endLine;

  while (!cursor.atEnd) {
    final line = cursor.peek()!;
    if (line.depth <= baseDepth) {
      break;
    }

    if (line.depth != rowDepth) {
      throw overIndentedLineError(line, rowDepth);
    }

    if (!isDataRow(line.content, header.delimiter)) {
      break;
    }

    startLine ??= line.lineNumber;
    endLine = line.lineNumber;

    cursor.advance();
    final values = parseDelimitedValues(line.content, header.delimiter);
    assertExpectedCount(values.length, leafCount, 'tabular row values', line);
    final cells = _withLine(line, () => mapRowValuesToPrimitives(values));
    objects.add(objectFromFields(fields, cells));
  }

  if (options.strict) {
    assertExpectedCount(
      objects.length,
      header.length,
      'tabular rows',
      cursor.current!,
    );
    validateNoBlankLinesInRange(
      startLine,
      endLine,
      cursor.blankLines,
      'tabular array',
    );
  }

  return objects;
}

JsonObject decodeKeyedObject(
  ArrayHeaderInfo header,
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
) {
  final obj = <String, JsonValue>{};
  final fields = header.fields!;
  final entryDepth = scopeContentDepth(cursor, baseDepth, options.strict);
  final leafCount = countLeafFields(fields);

  int? startLine;
  int? endLine;

  // A keyed scope ends only by dedent or end of input, so every line at entry
  // depth carrying an unquoted colon is an entry row.
  while (!cursor.atEnd) {
    final line = cursor.peek()!;
    if (line.depth <= baseDepth) {
      break;
    }

    if (line.depth != entryDepth) {
      throw overIndentedLineError(line, entryDepth);
    }

    cursor.advance();
    if (!isKeyValueContent(line.content)) {
      throw FormatException(
        'Line ${line.lineNumber}: Expected entry row inside keyed tabular object',
      );
    }

    startLine ??= line.lineNumber;
    endLine = line.lineNumber;

    final (:key, :end) = _withLine(line, () => parseKeyToken(line.content));
    _assertNewKey(obj, key, line, options.strict);

    final values = parseDelimitedValues(
      trimSpaces(line.content.substring(end)),
      header.delimiter,
    );
    assertExpectedCount(values.length, leafCount, 'keyed entry cells', line);
    final cells = _withLine(line, () => mapRowValuesToPrimitives(values));
    obj[key] = objectFromFields(fields, cells);
  }

  if (options.strict) {
    assertExpectedCount(
      obj.length,
      header.length,
      'keyed entries',
      cursor.current!,
    );
    validateNoBlankLinesInRange(
      startLine,
      endLine,
      cursor.blankLines,
      'keyed tabular object',
    );
  }

  return obj;
}

JsonValue decodeListItem(
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
) {
  final line = cursor.next()!;
  if (line.content == listItemMarker) {
    return <String, JsonValue>{};
  }

  final afterHyphen = trimSpaces(line.content.substring(listItemPrefix.length));
  if (afterHyphen == '[]') {
    return <JsonValue>[];
  }

  if (isArrayHeaderContent(afterHyphen)) {
    if (_withLine(line, () => resolveArrayHeader(afterHyphen, options.strict))
        case final result?) {
      final header = result.header;
      if (header.fields == null) {
        return decodeArrayFromHeader(
          header,
          result.inlineValues,
          cursor,
          baseDepth,
          options,
        );
      }
      // There is no keyless keyed or fields-bearing list-item form.
      throw FormatException(
        header.keyed
            ? 'Line ${line.lineNumber}: Keyless keyed header is only valid at the document root'
            : 'Line ${line.lineNumber}: Keyless header with a field list is only valid at the document root',
      );
    }
  }

  if (isKeyValueContent(afterHyphen)) {
    return decodeObjectFromListItem(afterHyphen, cursor, baseDepth, options);
  }

  return _withLine(line, () => parsePrimitiveToken(afterHyphen));
}

JsonObject decodeObjectFromListItem(
  String firstField,
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
) {
  // The first field's nested content sits at `baseDepth + 2`, its siblings at
  // `baseDepth + 1`.
  final fieldDepth = baseDepth + 1;
  final obj = <String, JsonValue>{};
  decodeField(firstField, cursor, fieldDepth, options, obj);

  while (!cursor.atEnd) {
    final line = cursor.peek()!;
    if (line.depth < fieldDepth) {
      break;
    }

    if (line.depth != fieldDepth) {
      throw overIndentedLineError(line, fieldDepth);
    }

    // A hyphen marks a list item only at item depth, so a `- ` line here is a
    // further field.
    cursor.advance();
    decodeField(line.content, cursor, fieldDepth, options, obj);
  }

  return obj;
}

/// Builds a row object from [cells] in depth-first field order.
JsonObject objectFromFields(List<FieldNode> fields, List<JsonPrimitive> cells) {
  var cellIndex = 0;

  JsonObject walk(List<FieldNode> nodes) {
    final obj = <String, JsonValue>{};
    for (final node in nodes) {
      if (node.children case final children?) {
        obj[node.name] = walk(children);
      } else {
        obj[node.name] = cells[cellIndex++];
      }
    }
    return obj;
  }

  return walk(fields);
}
