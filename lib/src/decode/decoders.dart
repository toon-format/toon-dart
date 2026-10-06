import '../options.dart';
import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string_utils.dart';
import 'parser.dart';
import 'scanners.dart';
import 'validation.dart';

JsonValue decodeValueFromLines(LineCursor cursor, DecodeOptions options) {
  var first = cursor.peek();
  while (first != null && first.depth != 0) {
    skipOverIndentedLine(cursor, first, 0, options.strict);
    first = cursor.peek();
  }
  if (first == null) {
    return <String, JsonValue>{};
  }
  final content = first.content;

  if (content == '[]') {
    cursor.advance();
    assertFullyConsumed(cursor, options.strict);
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
      assertFullyConsumed(cursor, options.strict);
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

/// Throws on a line deeper than [contentDepth] in strict mode and skips it in
/// non-strict mode.
void skipOverIndentedLine(
  LineCursor cursor,
  ParsedLine line,
  int contentDepth,
  bool strict,
) {
  if (strict) {
    throw FormatException(
      'Line ${line.lineNumber}: Over-indented line: expected depth $contentDepth, but found ${line.depth}',
    );
  }
  assertNotScalarLine(line);
  cursor.advance();
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

/// Strict decoding never silently discards input, so a line after the root
/// form is an error; non-strict decoding skips it unless it is a bare token.
void assertFullyConsumed(LineCursor cursor, bool strict) {
  final line = cursor.peek();
  if (line == null) return;
  if (strict) {
    throw FormatException(
      'Line ${line.lineNumber}: Unexpected content after the document root',
    );
  }
  while (!cursor.atEnd) {
    assertNotScalarLine(cursor.next()!);
  }
}

/// Both modes reject a bare token outside root primitive position.
void assertNotScalarLine(ParsedLine line) {
  if (!isKeyValueContent(line.content)) {
    throw FormatException(
      'Line ${line.lineNumber}: Unexpected bare token line outside root primitive position',
    );
  }
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
      skipOverIndentedLine(cursor, line, fieldDepth, options.strict);
      continue;
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
    if (options.strict) {
      throw FormatException(
        header.keyed
            ? 'Line ${line.lineNumber}: Keyless keyed header is only valid at the document root'
            : 'Line ${line.lineNumber}: Keyless array header is only valid at the document root or as a list item',
      );
    }
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

  assertExpectedCount(
    primitives.length,
    header.length,
    'inline array items',
    headerLine,
    options,
  );

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
      skipOverIndentedLine(cursor, line, itemDepth, options.strict);
      continue;
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

  assertExpectedCount(
    items.length,
    header.length,
    'list array items',
    cursor.current!,
    options,
  );

  if (options.strict && startLine != null && endLine != null) {
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
      skipOverIndentedLine(cursor, line, rowDepth, options.strict);
      continue;
    }

    if (!isDataRow(line.content, header.delimiter)) {
      break;
    }

    startLine ??= line.lineNumber;
    endLine = line.lineNumber;

    cursor.advance();
    final values = parseDelimitedValues(line.content, header.delimiter);
    assertExpectedCount(
      values.length,
      leafCount,
      'tabular row values',
      line,
      options,
    );
    final cells = _withLine(line, () => mapRowValuesToPrimitives(values));
    objects.add(objectFromFields(fields, cells));
  }

  assertExpectedCount(
    objects.length,
    header.length,
    'tabular rows',
    cursor.current!,
    options,
  );

  if (options.strict && startLine != null && endLine != null) {
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
      skipOverIndentedLine(cursor, line, entryDepth, options.strict);
      continue;
    }

    cursor.advance();
    if (!isKeyValueContent(line.content)) {
      if (options.strict) {
        throw FormatException(
          'Line ${line.lineNumber}: Expected entry row inside keyed tabular object',
        );
      }
      continue;
    }

    startLine ??= line.lineNumber;
    endLine = line.lineNumber;

    final (:key, :end) = _withLine(line, () => parseKeyToken(line.content));
    _assertNewKey(obj, key, line, options.strict);

    final values = parseDelimitedValues(
      trimSpaces(line.content.substring(end)),
      header.delimiter,
    );
    assertExpectedCount(
      values.length,
      leafCount,
      'keyed entry cells',
      line,
      options,
    );
    final cells = _withLine(line, () => mapRowValuesToPrimitives(values));
    obj[key] = objectFromFields(fields, cells);
  }

  assertExpectedCount(
    obj.length,
    header.length,
    'keyed entries',
    cursor.current!,
    options,
  );

  if (options.strict && startLine != null && endLine != null) {
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

  final afterHyphen = line.content.substring(listItemPrefix.length);
  if (trimSpaces(afterHyphen) == '[]') {
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
      if (options.strict) {
        throw FormatException(
          header.keyed
              ? 'Line ${line.lineNumber}: Keyless keyed header is only valid at the document root'
              : 'Line ${line.lineNumber}: Keyless header with a field list is only valid at the document root',
        );
      }
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

    // A hyphen marks a list item only at item depth, so a `- ` line here is a
    // further field.
    if (line.depth == fieldDepth) {
      cursor.advance();
      decodeField(line.content, cursor, fieldDepth, options, obj);
    } else {
      skipOverIndentedLine(cursor, line, fieldDepth, options.strict);
    }
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
      } else if (cellIndex < cells.length) {
        // A non-strict width mismatch leaves trailing leaves absent.
        obj[node.name] = cells[cellIndex++];
      }
    }
    return obj;
  }

  return walk(fields);
}
