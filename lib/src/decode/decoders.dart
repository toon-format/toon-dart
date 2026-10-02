import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string-utils.dart';
import 'parser.dart';
import 'scanners.dart';
import 'validation.dart';

// #region Entry decoding

/// Decodes a value from lines.
JsonValue decodeValueFromLines(LineCursor cursor, ResolvedDecodeOptions options) {
  final first = cursor.peek();
  if (first == null) {
    return <String, JsonValue>{};
  }

  // Check for root array
  if (isArrayHeaderAfterHyphen(first.content)) {
    final headerInfo = parseArrayHeaderLine(first.content, DEFAULT_DELIMITER);
    if (headerInfo != null) {
      cursor.advance(); // Move past the header line
      return decodeArrayFromHeader(headerInfo.header, headerInfo.inlineValues, cursor, 0, options);
    }
  }

  // Check for single primitive value
  if (cursor.length == 1 && !isKeyValueLine(first)) {
    return parsePrimitiveToken(first.content.trim());
  }

  // Default to object
  return decodeObject(cursor, 0, options);
}

/// Checks if a line is a key-value line.
bool isKeyValueLine(ParsedLine line) {
  final content = line.content;
  // Look for unquoted colon or quoted key followed by colon
  if (content.startsWith('"')) {
    // Quoted key - find the closing quote
    final closingQuoteIndex = findClosingQuote(content, 0);
    if (closingQuoteIndex == -1) {
      return false;
    }
    // Check if colon exists after quoted key (may have array/brace syntax between)
    return content.substring(closingQuoteIndex + 1).contains(COLON);
  } else {
    // Unquoted key - look for first colon not inside quotes
    return content.contains(COLON);
  }
}

// #endregion

// #region Object decoding

/// Decodes an object from lines.
JsonObject decodeObject(LineCursor cursor, Depth baseDepth, ResolvedDecodeOptions options) {
  final obj = <String, JsonValue>{};

  // Detect the actual depth of the first field (may differ from baseDepth in nested structures)
  Depth? computedDepth;

  while (!cursor.atEnd()) {
    final line = cursor.peek();
    if (line == null || line.depth < baseDepth) {
      break;
    }

    if (computedDepth == null && line.depth >= baseDepth) {
      computedDepth = line.depth;
    }

    if (computedDepth != null && line.depth == computedDepth) {
      final pair = decodeKeyValuePair(line, cursor, computedDepth, options);
      obj[pair.key] = pair.value;
    } else {
      // Different depth (shallower or deeper) - stop object parsing
      break;
    }
  }

  return obj;
}

/// Decodes a key-value pair from content.
KeyValueResult decodeKeyValue(
  String content,
  LineCursor cursor,
  Depth baseDepth,
  ResolvedDecodeOptions options,
) {
  // Check for array header first (before parsing key)
  final arrayHeader = parseArrayHeaderLine(content, DEFAULT_DELIMITER);
  if (arrayHeader != null && arrayHeader.header.key != null) {
    final value = decodeArrayFromHeader(arrayHeader.header, arrayHeader.inlineValues, cursor, baseDepth, options);
    // After an array, subsequent fields are at baseDepth + 1 (where array content is)
    return KeyValueResult(
      key: arrayHeader.header.key!,
      value: value,
      followDepth: baseDepth + 1,
    );
  }

  // Regular key-value pair
  final keyToken = parseKeyToken(content, 0);
  final rest = content.substring(keyToken.end).trim();

  // No value after colon - expect nested object or empty
  if (rest.isEmpty) {
    final nextLine = cursor.peek();
    if (nextLine != null && nextLine.depth > baseDepth) {
      final nested = decodeObject(cursor, baseDepth + 1, options);
      return KeyValueResult(key: keyToken.key, value: nested, followDepth: baseDepth + 1);
    }
    // Empty object
    return KeyValueResult(key: keyToken.key, value: const <String, JsonValue>{}, followDepth: baseDepth + 1);
  }

  // Inline primitive value
  final value = parsePrimitiveToken(rest);
  return KeyValueResult(key: keyToken.key, value: value, followDepth: baseDepth + 1);
}

/// Decodes a key-value pair from a line.
KeyValuePairResult decodeKeyValuePair(
  ParsedLine line,
  LineCursor cursor,
  Depth baseDepth,
  ResolvedDecodeOptions options,
) {
  cursor.advance();
  final result = decodeKeyValue(line.content, cursor, baseDepth, options);
  return KeyValuePairResult(key: result.key, value: result.value);
}

// #endregion

// #region Array decoding

/// Decodes an array from a header.
JsonArray decodeArrayFromHeader(
  ArrayHeaderInfo header,
  String? inlineValues,
  LineCursor cursor,
  Depth baseDepth,
  ResolvedDecodeOptions options,
) {
  // Inline primitive array
  if (inlineValues != null) {
    // For inline arrays, cursor should already be advanced or will be by caller
    return decodeInlinePrimitiveArray(header, inlineValues, options);
  }

  // For multi-line arrays (tabular or list), the cursor should already be positioned
  // at the array header line, but we haven't advanced past it yet

  // Tabular array
  if (header.fields != null && header.fields!.isNotEmpty) {
    return decodeTabularArray(header, cursor, baseDepth, options);
  }

  // List array
  return decodeListArray(header, cursor, baseDepth, options);
}

/// Decodes an inline primitive array.
List<JsonPrimitive> decodeInlinePrimitiveArray(
  ArrayHeaderInfo header,
  String inlineValues,
  ResolvedDecodeOptions options,
) {
  if (inlineValues.trim().isEmpty) {
    assertExpectedCount(0, header.length, 'inline array items', options);
    return [];
  }

  final values = parseDelimitedValues(inlineValues, header.delimiter);
  final primitives = mapRowValuesToPrimitives(values);

  assertExpectedCount(primitives.length, header.length, 'inline array items', options);

  return primitives;
}

/// Decodes a list array.
List<JsonValue> decodeListArray(
  ArrayHeaderInfo header,
  LineCursor cursor,
  Depth baseDepth,
  ResolvedDecodeOptions options,
) {
  final items = <JsonValue>[];
  final itemDepth = baseDepth + 1;

  // Track line range for blank line validation
  int? startLine;
  int? endLine;

  while (!cursor.atEnd() && items.length < header.length) {
    final line = cursor.peek();
    if (line == null || line.depth < itemDepth) {
      break;
    }

    // Check for list item (with or without space after hyphen)
    final isListItem = line.content.startsWith(LIST_ITEM_PREFIX) || line.content == '-';

    if (line.depth == itemDepth && isListItem) {
      // Track first and last item line numbers
      if (startLine == null) {
        startLine = line.lineNumber;
      }
      endLine = line.lineNumber;

      final item = decodeListItem(cursor, itemDepth, options);
      items.add(item);

      // Update endLine to the current cursor position (after item was decoded)
      final currentLine = cursor.current();
      if (currentLine != null) {
        endLine = currentLine.lineNumber;
      }
    } else {
      break;
    }
  }

  assertExpectedCount(items.length, header.length, 'list array items', options);

  // In strict mode, check for blank lines inside the array
  if (options.strict && startLine != null && endLine != null) {
    validateNoBlankLinesInRange(
      startLine, // From first item line
      endLine, // To last item line
      cursor.getBlankLines(),
      options.strict,
      'list array',
    );
  }

  // In strict mode, check for extra items
  if (options.strict) {
    validateNoExtraListItems(cursor, itemDepth, header.length);
  }

  return items;
}

/// Decodes a tabular array.
List<JsonObject> decodeTabularArray(
  ArrayHeaderInfo header,
  LineCursor cursor,
  Depth baseDepth,
  ResolvedDecodeOptions options,
) {
  final objects = <JsonObject>[];
  final rowDepth = baseDepth + 1;

  // Track line range for blank line validation
  int? startLine;
  int? endLine;

  while (!cursor.atEnd() && objects.length < header.length) {
    final line = cursor.peek();
    if (line == null || line.depth < rowDepth) {
      break;
    }

    if (line.depth == rowDepth) {
      // Track first and last row line numbers
      startLine ??= line.lineNumber;
      endLine = line.lineNumber;

      cursor.advance();
      final values = parseDelimitedValues(line.content, header.delimiter);
      assertExpectedCount(values.length, header.fields!.length, 'tabular row values', options);

      final primitives = mapRowValuesToPrimitives(values);
      final obj = <String, JsonValue>{};

      for (int i = 0; i < header.fields!.length; i++) {
        obj[header.fields![i]] = primitives[i];
      }

      objects.add(obj);
    } else {
      break;
    }
  }

  assertExpectedCount(objects.length, header.length, 'tabular rows', options);

  // In strict mode, check for blank lines inside the array
  if (options.strict && startLine != null && endLine != null) {
    validateNoBlankLinesInRange(
      startLine, // From first row line
      endLine, // To last row line
      cursor.getBlankLines(),
      options.strict,
      'tabular array',
    );
  }

  // In strict mode, check for extra rows
  if (options.strict) {
    validateNoExtraTabularRows(cursor, rowDepth, header);
  }

  return objects;
}

// #endregion

// #region List item decoding

/// Decodes a list item.
JsonValue decodeListItem(
  LineCursor cursor,
  Depth baseDepth,
  ResolvedDecodeOptions options,
) {
  final line = cursor.next();
  if (line == null) {
    throw StateError('Expected list item');
  }

  // Check for list item (with or without space after hyphen)
  String afterHyphen;

  // Empty list item should be an empty object
  if (line.content == '-') {
    return <String, JsonValue>{};
  } else if (line.content.startsWith(LIST_ITEM_PREFIX)) {
    afterHyphen = line.content.substring(LIST_ITEM_PREFIX.length);
  } else {
    throw FormatException('Expected list item to start with "$LIST_ITEM_PREFIX"');
  }

  // Empty content after list item should also be an empty object
  if (afterHyphen.trim().isEmpty) {
    return <String, JsonValue>{};
  }

  // Check for array header after hyphen
  if (isArrayHeaderAfterHyphen(afterHyphen)) {
    final arrayHeader = parseArrayHeaderLine(afterHyphen, DEFAULT_DELIMITER);
    if (arrayHeader != null) {
      return decodeArrayFromHeader(arrayHeader.header, arrayHeader.inlineValues, cursor, baseDepth, options);
    }
  }

  // Check for object first field after hyphen
  if (isObjectFirstFieldAfterHyphen(afterHyphen)) {
    return decodeObjectFromListItem(line, cursor, baseDepth, options);
  }

  // Primitive value
  return parsePrimitiveToken(afterHyphen);
}

/// Decodes an object from a list item.
JsonObject decodeObjectFromListItem(
  ParsedLine firstLine,
  LineCursor cursor,
  Depth baseDepth,
  ResolvedDecodeOptions options,
) {
  final afterHyphen = firstLine.content.substring(LIST_ITEM_PREFIX.length);
  final result = decodeKeyValue(afterHyphen, cursor, baseDepth, options);

  final obj = <String, JsonValue>{result.key: result.value};

  // Read subsequent fields
  while (!cursor.atEnd()) {
    final line = cursor.peek();
    if (line == null || line.depth < result.followDepth) {
      break;
    }

    if (line.depth == result.followDepth && !line.content.startsWith(LIST_ITEM_PREFIX)) {
      final pair = decodeKeyValuePair(line, cursor, result.followDepth, options);
      obj[pair.key] = pair.value;
    } else {
      break;
    }
  }

  return obj;
}

// #endregion
