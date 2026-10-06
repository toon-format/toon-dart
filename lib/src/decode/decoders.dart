import '../options.dart';
import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string_utils.dart';
import 'parser.dart';
import 'scanners.dart';
import 'validation.dart';

// #region Entry decoding

JsonValue decodeValueFromLines(LineCursor cursor, DecodeOptions options) {
  final first = cursor.peek();
  if (first == null) {
    return <String, JsonValue>{};
  }

  if (trimSpaces(first.content) == '[]') {
    cursor.advance();
    assertFullyConsumed(cursor, options.strict);
    return <JsonValue>[];
  }

  if (isArrayHeaderContent(first.content)) {
    final headerInfo = resolveArrayHeader(first.content, options.strict);
    if (headerInfo != null) {
      cursor.advance();
      return decodeArrayFromHeader(
        headerInfo.header,
        headerInfo.inlineValues,
        cursor,
        0,
        options,
      );
    }
  }

  if (cursor.length == 1 && !isKeyValueContent(first.content)) {
    return parsePrimitiveToken(trimSpaces(first.content));
  }

  return decodeObject(cursor, 0, options);
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
  while (!cursor.atEnd()) {
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

// #endregion

// #region Object decoding

JsonObject decodeObject(
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
) {
  final obj = <String, JsonValue>{};

  // The first field sets the depth, which can sit deeper than `baseDepth` in
  // nested structures.
  int? computedDepth;

  while (!cursor.atEnd()) {
    final line = cursor.peek()!;
    if (line.depth < baseDepth) {
      break;
    }

    computedDepth ??= line.depth;
    if (line.depth != computedDepth) {
      break;
    }

    cursor.advance();
    decodeField(line.content, cursor, computedDepth, options, obj);
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
  final arrayHeader = resolveArrayHeader(content, options.strict);
  if (arrayHeader != null && arrayHeader.header.key != null) {
    final key = arrayHeader.header.key!;
    _assertNewKey(obj, key, options.strict);
    obj[key] = decodeArrayFromHeader(
      arrayHeader.header,
      arrayHeader.inlineValues,
      cursor,
      baseDepth,
      options,
    );
    return;
  }

  final (:key, :end) = parseKeyToken(content, 0);
  final rest = trimSpaces(content.substring(end));
  _assertNewKey(obj, key, options.strict);

  if (rest.isEmpty) {
    final nextLine = cursor.peek();
    obj[key] = nextLine != null && nextLine.depth > baseDepth
        ? decodeObject(cursor, baseDepth + 1, options)
        : <String, JsonValue>{};
    return;
  }

  obj[key] = rest == '[]' ? <JsonValue>[] : parsePrimitiveToken(rest);
}

/// Strict mode rejects duplicate sibling keys; non-strict mode lets the last
/// write win.
void _assertNewKey(JsonObject obj, String key, bool strict) {
  if (strict && obj.containsKey(key)) {
    throw FormatException('Duplicate sibling key "$key"');
  }
}

// #endregion

// #region Array decoding

JsonArray decodeArrayFromHeader(
  ArrayHeaderInfo header,
  String? inlineValues,
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
) {
  if (inlineValues != null) {
    return decodeInlinePrimitiveArray(header, inlineValues, options);
  }

  if (header.fields != null && header.fields!.isNotEmpty) {
    return decodeTabularArray(header, cursor, baseDepth, options);
  }

  return decodeListArray(header, cursor, baseDepth, options);
}

List<JsonPrimitive> decodeInlinePrimitiveArray(
  ArrayHeaderInfo header,
  String inlineValues,
  DecodeOptions options,
) {
  if (trimSpaces(inlineValues).isEmpty) {
    assertExpectedCount(0, header.length, 'inline array items', options);
    return [];
  }

  final values = parseDelimitedValues(inlineValues, header.delimiter);
  final primitives = mapRowValuesToPrimitives(values);

  assertExpectedCount(
    primitives.length,
    header.length,
    'inline array items',
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
  final itemDepth = baseDepth + 1;

  int? startLine;
  int? endLine;

  while (!cursor.atEnd() && items.length < header.length) {
    final line = cursor.peek();
    if (line == null || line.depth < itemDepth) {
      break;
    }

    final isListItem =
        line.content.startsWith(listItemPrefix) || line.content == '-';

    if (line.depth == itemDepth && isListItem) {
      startLine ??= line.lineNumber;
      endLine = line.lineNumber;

      final item = decodeListItem(cursor, itemDepth, options);
      items.add(item);

      final currentLine = cursor.current();
      if (currentLine != null) {
        endLine = currentLine.lineNumber;
      }
    } else {
      break;
    }
  }

  assertExpectedCount(items.length, header.length, 'list array items', options);

  if (options.strict && startLine != null && endLine != null) {
    validateNoBlankLinesInRange(
      startLine,
      endLine,
      cursor.getBlankLines(),
      options.strict,
      'list array',
    );
  }

  if (options.strict) {
    validateNoExtraListItems(cursor, itemDepth, header.length);
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
  final rowDepth = baseDepth + 1;

  int? startLine;
  int? endLine;

  while (!cursor.atEnd() && objects.length < header.length) {
    final line = cursor.peek();
    if (line == null || line.depth < rowDepth) {
      break;
    }

    if (line.depth == rowDepth) {
      startLine ??= line.lineNumber;
      endLine = line.lineNumber;

      cursor.advance();
      final values = parseDelimitedValues(line.content, header.delimiter);
      assertExpectedCount(
        values.length,
        countLeafFields(header.fields!),
        'tabular row values',
        options,
      );

      final obj = objectFromFields(
        header.fields!,
        mapRowValuesToPrimitives(values),
      );
      objects.add(obj);
    } else {
      break;
    }
  }

  assertExpectedCount(objects.length, header.length, 'tabular rows', options);

  if (options.strict && startLine != null && endLine != null) {
    validateNoBlankLinesInRange(
      startLine,
      endLine,
      cursor.getBlankLines(),
      options.strict,
      'tabular array',
    );
  }

  if (options.strict) {
    validateNoExtraTabularRows(cursor, rowDepth, header);
  }

  return objects;
}

// #endregion

// #region List item decoding

JsonValue decodeListItem(
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
) {
  final line = cursor.next();
  if (line == null) {
    throw StateError('Expected list item');
  }

  String afterHyphen;

  if (line.content == '-') {
    return <String, JsonValue>{};
  } else if (line.content.startsWith(listItemPrefix)) {
    afterHyphen = line.content.substring(listItemPrefix.length);
  } else {
    throw const FormatException(
      'Expected list item to start with "$listItemPrefix"',
    );
  }

  if (trimSpaces(afterHyphen).isEmpty) {
    return <String, JsonValue>{};
  }

  if (trimSpaces(afterHyphen) == '[]') {
    return <JsonValue>[];
  }

  if (isArrayHeaderContent(afterHyphen)) {
    final arrayHeader = resolveArrayHeader(afterHyphen, options.strict);
    if (arrayHeader != null) {
      return decodeArrayFromHeader(
        arrayHeader.header,
        arrayHeader.inlineValues,
        cursor,
        baseDepth,
        options,
      );
    }
  }

  if (isKeyValueContent(afterHyphen)) {
    return decodeObjectFromListItem(line, cursor, baseDepth, options);
  }

  return parsePrimitiveToken(afterHyphen);
}

JsonObject decodeObjectFromListItem(
  ParsedLine firstLine,
  LineCursor cursor,
  int baseDepth,
  DecodeOptions options,
) {
  // The first field's nested content sits at `baseDepth + 2`, its siblings at
  // `baseDepth + 1`.
  final fieldDepth = baseDepth + 1;
  final afterHyphen = firstLine.content.substring(listItemPrefix.length);
  final obj = <String, JsonValue>{};
  decodeField(afterHyphen, cursor, fieldDepth, options, obj);

  while (!cursor.atEnd()) {
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
      break;
    }
  }

  return obj;
}

// #endregion

// #region Shared decoder helpers

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

// #endregion
