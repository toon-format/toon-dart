import '../types.dart';
import '../utilities/constants.dart';
import 'normalize.dart';
import 'primitives.dart';
import 'writer.dart';

// #region Encode normalized JsonValue

/// Encodes a JsonValue to TOON format.
String encodeValue(JsonValue value, ResolvedEncodeOptions options) {
  if (isJsonPrimitive(value)) {
    return encodePrimitive(value, options.delimiter);
  }

  final writer = LineWriter(options.indent);

  if (isJsonArray(value)) {
    encodeArray(null, value as JsonArray, writer, 0, options);
  } else if (isJsonObject(value)) {
    encodeObject(value as JsonObject, writer, 0, options);
  }

  return writer.toString();
}

// #endregion

// #region Object encoding

/// Encodes a JSON object.
void encodeObject(JsonObject value, LineWriter writer, Depth depth, ResolvedEncodeOptions options) {
  final keys = value.keys.toList();

  for (final key in keys) {
    encodeKeyValuePair(key, value[key], writer, depth, options);
  }
}

/// Encodes a key-value pair.
void encodeKeyValuePair(String key, JsonValue? value, LineWriter writer, Depth depth, ResolvedEncodeOptions options) {
  final encodedKey = encodeKey(key);

  if (isJsonPrimitive(value)) {
    writer.push(depth, '$encodedKey: ${encodePrimitive(value, options.delimiter)}');
  } else if (isJsonArray(value)) {
    encodeArray(key, value as JsonArray, writer, depth, options);
  } else if (isJsonObject(value)) {
    final nestedKeys = (value as JsonObject).keys.toList();
    if (nestedKeys.isEmpty) {
      // Empty object
      writer.push(depth, '$encodedKey:');
    } else {
      writer.push(depth, '$encodedKey:');
      encodeObject(value, writer, depth + 1, options);
    }
  }
}

// #endregion

// #region Array encoding

/// Encodes a JSON array.
void encodeArray(
  String? key,
  JsonArray value,
  LineWriter writer,
  Depth depth,
  ResolvedEncodeOptions options,
) {
  if (value.isEmpty) {
    final header = formatHeader(0, key: key, delimiter: options.delimiter, lengthMarker: options.lengthMarker);
    writer.push(depth, header);
    return;
  }

  // Primitive array
  if (isArrayOfPrimitives(value)) {
    final formatted = encodeInlineArrayLine(value, options.delimiter, key, options.lengthMarker);
    writer.push(depth, formatted);
    return;
  }

  // Array of arrays (all primitives)
  if (isArrayOfArrays(value)) {
    final allPrimitiveArrays = value.every((arr) => isArrayOfPrimitives(arr as JsonArray));
    if (allPrimitiveArrays) {
      encodeArrayOfArraysAsListItems(key, value.cast<JsonArray>(), writer, depth, options);
      return;
    }
  }

  // Array of objects
  if (isArrayOfObjects(value)) {
    final objects = value.cast<JsonObject>();
    final header = extractTabularHeader(objects);
    if (header != null) {
      encodeArrayOfObjectsAsTabular(key, objects, header, writer, depth, options);
    } else {
      encodeMixedArrayAsListItems(key, value, writer, depth, options);
    }
    return;
  }

  // Mixed array: fallback to expanded format
  encodeMixedArrayAsListItems(key, value, writer, depth, options);
}

// #endregion

// #region Array of arrays (expanded format)

/// Encodes an array of arrays as list items.
void encodeArrayOfArraysAsListItems(
  String? prefix,
  List<JsonArray> values,
  LineWriter writer,
  Depth depth,
  ResolvedEncodeOptions options,
) {
  final header = formatHeader(values.length, key: prefix, delimiter: options.delimiter, lengthMarker: options.lengthMarker);
  writer.push(depth, header);

  for (final arr in values) {
    if (isArrayOfPrimitives(arr)) {
      final inline = encodeInlineArrayLine(arr, options.delimiter, null, options.lengthMarker);
      writer.pushListItem(depth + 1, inline);
    }
  }
}

/// Encodes an inline array line.
String encodeInlineArrayLine(List<JsonPrimitive> values, String delimiter, String? prefix, String? lengthMarker) {
  final header = formatHeader(values.length, key: prefix, delimiter: delimiter, lengthMarker: lengthMarker);
  final joinedValue = encodeAndJoinPrimitives(values, delimiter);
  // Only add space if there are values
  if (values.isEmpty) {
    return header;
  }
  return '$header $joinedValue';
}

// #endregion

// #region Array of objects (tabular format)

/// Encodes an array of objects in tabular format.
void encodeArrayOfObjectsAsTabular(
  String? prefix,
  List<JsonObject> rows,
  List<String> header,
  LineWriter writer,
  Depth depth,
  ResolvedEncodeOptions options,
) {
  final formattedHeader = formatHeader(rows.length, key: prefix, fields: header, delimiter: options.delimiter, lengthMarker: options.lengthMarker);
  writer.push(depth, formattedHeader);

  writeTabularRows(rows, header, writer, depth + 1, options);
}

/// Extracts the tabular header from an array of objects.
List<String>? extractTabularHeader(List<JsonObject> rows) {
  if (rows.isEmpty) return null;

  final firstRow = rows[0];
  final firstKeys = firstRow.keys.toList();
  if (firstKeys.isEmpty) return null;

  if (isTabularArray(rows, firstKeys)) {
    return firstKeys;
  }
  return null;
}

/// Checks if an array of objects is tabular (all have same keys and primitive values).
bool isTabularArray(
  List<JsonObject> rows,
  List<String> header,
) {
  for (final row in rows) {
    final keys = row.keys.toList();

    // All objects must have the same keys (but order can differ)
    if (keys.length != header.length) {
      return false;
    }

    // Check that all header keys exist in the row and all values are primitives
    for (final key in header) {
      if (!row.containsKey(key)) {
        return false;
      }
      if (!isJsonPrimitive(row[key])) {
        return false;
      }
    }
  }

  return true;
}

/// Writes tabular rows.
void writeTabularRows(
  List<JsonObject> rows,
  List<String> header,
  LineWriter writer,
  Depth depth,
  ResolvedEncodeOptions options,
) {
  for (final row in rows) {
    final values = header.map((key) => row[key]).toList();
    final joinedValue = encodeAndJoinPrimitives(values, options.delimiter);
    writer.push(depth, joinedValue);
  }
}

// #endregion

// #region Array of objects (expanded format)

/// Encodes a mixed array as list items.
void encodeMixedArrayAsListItems(
  String? prefix,
  List<JsonValue> items,
  LineWriter writer,
  Depth depth,
  ResolvedEncodeOptions options,
) {
  final header = formatHeader(items.length, key: prefix, delimiter: options.delimiter, lengthMarker: options.lengthMarker);
  writer.push(depth, header);

  for (final item in items) {
    encodeListItemValue(item, writer, depth + 1, options);
  }
}

/// Encodes an object as a list item.
void encodeObjectAsListItem(JsonObject obj, LineWriter writer, Depth depth, ResolvedEncodeOptions options) {
  final keys = obj.keys.toList();
  if (keys.isEmpty) {
    writer.push(depth, LIST_ITEM_MARKER);
    return;
  }

  // First key-value on the same line as "- "
  final firstKey = keys[0];
  final encodedKey = encodeKey(firstKey);
  final firstValue = obj[firstKey];

  if (isJsonPrimitive(firstValue)) {
    writer.pushListItem(depth, '$encodedKey: ${encodePrimitive(firstValue, options.delimiter)}');
  } else if (isJsonArray(firstValue)) {
    final arr = firstValue as JsonArray;
    if (isArrayOfPrimitives(arr)) {
      // Inline format for primitive arrays
      final formatted = encodeInlineArrayLine(arr, options.delimiter, firstKey, options.lengthMarker);
      writer.pushListItem(depth, formatted);
    } else if (isArrayOfObjects(arr)) {
      // Check if array of objects can use tabular format
      final objects = arr.cast<JsonObject>();
      final header = extractTabularHeader(objects);
      if (header != null) {
        // Tabular format for uniform arrays of objects
        final formattedHeader = formatHeader(arr.length, key: firstKey, fields: header, delimiter: options.delimiter, lengthMarker: options.lengthMarker);
        writer.pushListItem(depth, formattedHeader);
        writeTabularRows(objects, header, writer, depth + 1, options);
      } else {
        // Fall back to list format for non-uniform arrays of objects
        writer.pushListItem(depth, '$encodedKey[${arr.length}]:');
        for (final item in arr) {
          encodeObjectAsListItem(item as JsonObject, writer, depth + 1, options);
        }
      }
    } else {
      // Complex arrays on separate lines (array of arrays, etc.)
      writer.pushListItem(depth, '$encodedKey[${arr.length}]:');

      // Encode array contents at depth + 1
      for (final item in arr) {
        encodeListItemValue(item, writer, depth + 1, options);
      }
    }
  } else if (isJsonObject(firstValue)) {
    final nestedKeys = (firstValue as JsonObject).keys.toList();
    if (nestedKeys.isEmpty) {
      writer.pushListItem(depth, '$encodedKey:');
    } else {
      writer.pushListItem(depth, '$encodedKey:');
      encodeObject(firstValue, writer, depth + 2, options);
    }
  }

  // Remaining keys on indented lines
  for (int i = 1; i < keys.length; i++) {
    final key = keys[i];
    encodeKeyValuePair(key, obj[key], writer, depth + 1, options);
  }
}

// #endregion

// #region List item encoding helpers

/// Encodes a list item value.
void encodeListItemValue(
  JsonValue value,
  LineWriter writer,
  Depth depth,
  ResolvedEncodeOptions options,
) {
  if (isJsonPrimitive(value)) {
    writer.pushListItem(depth, encodePrimitive(value, options.delimiter));
  } else if (isJsonArray(value)) {
    final arr = value as JsonArray;
    if (isArrayOfPrimitives(arr)) {
      final inline = encodeInlineArrayLine(arr, options.delimiter, null, options.lengthMarker);
      writer.pushListItem(depth, inline);
    }
  } else if (isJsonObject(value)) {
    encodeObjectAsListItem(value as JsonObject, writer, depth, options);
  }
}

// #endregion

// #endregion