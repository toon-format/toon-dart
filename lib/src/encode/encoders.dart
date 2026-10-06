import '../options.dart';
import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string_utils.dart';
import 'normalize.dart';
import 'primitives.dart';
import 'writer.dart';

// #region Encode normalized JsonValue

String encodeValue(JsonValue value, EncodeOptions options) {
  // Unquoted, a leading U+FEFF would be read as the document's byte-order mark
  // and stripped on decode.
  if (value is String && value.startsWith(byteOrderMark)) {
    return '$doubleQuote${escapeString(value)}$doubleQuote';
  }
  if (isJsonPrimitive(value)) {
    return encodePrimitive(value, options.delimiter);
  }

  final writer = LineWriter(options.indentSize);

  if (isJsonArray(value)) {
    encodeArray(null, value as JsonArray, writer, 0, options);
  } else if (isJsonObject(value)) {
    encodeObject(value as JsonObject, writer, 0, options);
  }

  return writer.toString();
}

// #endregion

// #region Object encoding

void encodeObject(
  JsonObject value,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  final keys = value.keys.toList();

  for (final key in keys) {
    encodeKeyValuePair(key, value[key], writer, depth, options);
  }
}

void encodeKeyValuePair(
  String key,
  JsonValue? value,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  final encodedKey = encodeKey(key);

  if (isJsonPrimitive(value)) {
    writer.push(
      depth,
      '$encodedKey: ${encodePrimitive(value, options.delimiter)}',
    );
  } else if (isJsonArray(value)) {
    encodeArray(key, value as JsonArray, writer, depth, options);
  } else if (isJsonObject(value)) {
    final nestedKeys = (value as JsonObject).keys.toList();
    if (nestedKeys.isEmpty) {
      writer.push(depth, '$encodedKey:');
    } else {
      writer.push(depth, '$encodedKey:');
      encodeObject(value, writer, depth + 1, options);
    }
  }
}

// #endregion

// #region Array encoding

void encodeArray(
  String? key,
  JsonArray value,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  if (value.isEmpty) {
    writer.push(depth, key == null ? '[]' : '${encodeKey(key)}: []');
    return;
  }

  if (isArrayOfPrimitives(value)) {
    final formatted = encodeInlineArrayLine(value, options.delimiter, key);
    writer.push(depth, formatted);
    return;
  }

  if (isArrayOfArrays(value)) {
    final allPrimitiveArrays = value.every(
      (arr) => isArrayOfPrimitives(arr as JsonArray),
    );
    if (allPrimitiveArrays) {
      encodeArrayOfArraysAsListItems(
        key,
        value.cast<JsonArray>(),
        writer,
        depth,
        options,
      );
      return;
    }
  }

  if (isArrayOfObjects(value)) {
    final objects = value.cast<JsonObject>();
    final header = extractTabularHeader(objects);
    if (header != null) {
      encodeArrayOfObjectsAsTabular(
        key,
        objects,
        header,
        writer,
        depth,
        options,
      );
    } else {
      encodeMixedArrayAsListItems(key, value, writer, depth, options);
    }
    return;
  }

  encodeMixedArrayAsListItems(key, value, writer, depth, options);
}

// #endregion

// #region Array of arrays (expanded format)

void encodeArrayOfArraysAsListItems(
  String? prefix,
  List<JsonArray> values,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  final header = formatHeader(
    values.length,
    key: prefix,
    delimiter: options.delimiter,
  );
  writer.push(depth, header);

  for (final arr in values) {
    if (isArrayOfPrimitives(arr)) {
      final inline = encodeInlineArrayLine(arr, options.delimiter, null);
      writer.pushListItem(depth + 1, inline);
    }
  }
}

String encodeInlineArrayLine(
  List<JsonPrimitive> values,
  String delimiter,
  String? prefix,
) {
  final header = formatHeader(values.length, key: prefix, delimiter: delimiter);
  final joinedValue = encodeAndJoinPrimitives(values, delimiter);
  if (values.isEmpty) {
    return header;
  }
  return '$header $joinedValue';
}

// #endregion

// #region Array of objects (tabular format)

void encodeArrayOfObjectsAsTabular(
  String? prefix,
  List<JsonObject> rows,
  List<String> header,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  final formattedHeader = formatHeader(
    rows.length,
    key: prefix,
    fields: header,
    delimiter: options.delimiter,
  );
  writer.push(depth, formattedHeader);

  writeTabularRows(rows, header, writer, depth + 1, options);
}

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

bool isTabularArray(List<JsonObject> rows, List<String> header) {
  for (final row in rows) {
    final keys = row.keys.toList();

    // Rows may list the same keys in a different order.
    if (keys.length != header.length) {
      return false;
    }

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

void writeTabularRows(
  List<JsonObject> rows,
  List<String> header,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  for (final row in rows) {
    final values = header.map((key) => row[key]).toList();
    final joinedValue = encodeAndJoinPrimitives(values, options.delimiter);
    writer.push(depth, joinedValue);
  }
}

// #endregion

// #region Array of objects (expanded format)

void encodeMixedArrayAsListItems(
  String? prefix,
  List<JsonValue> items,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  final header = formatHeader(
    items.length,
    key: prefix,
    delimiter: options.delimiter,
  );
  writer.push(depth, header);

  for (final item in items) {
    encodeListItemValue(item, writer, depth + 1, options);
  }
}

void encodeObjectAsListItem(
  JsonObject obj,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  final keys = obj.keys.toList();
  if (keys.isEmpty) {
    writer.push(depth, listItemMarker);
    return;
  }

  final firstKey = keys[0];
  final encodedKey = encodeKey(firstKey);
  final firstValue = obj[firstKey];

  if (isJsonPrimitive(firstValue)) {
    writer.pushListItem(
      depth,
      '$encodedKey: ${encodePrimitive(firstValue, options.delimiter)}',
    );
  } else if (isJsonArray(firstValue)) {
    final arr = firstValue as JsonArray;
    if (arr.isEmpty) {
      writer.pushListItem(depth, '$encodedKey: []');
    } else if (isArrayOfPrimitives(arr)) {
      final formatted = encodeInlineArrayLine(arr, options.delimiter, firstKey);
      writer.pushListItem(depth, formatted);
    } else {
      final objects = isArrayOfObjects(arr) ? arr.cast<JsonObject>() : null;
      final fields = objects == null ? null : extractTabularHeader(objects);
      if (fields != null) {
        final header = formatHeader(
          arr.length,
          key: firstKey,
          fields: fields,
          delimiter: options.delimiter,
        );
        writer.pushListItem(depth, header);
        writeTabularRows(objects!, fields, writer, depth + 2, options);
      } else {
        final header = formatHeader(arr.length, delimiter: options.delimiter);
        writer.pushListItem(depth, '$encodedKey$header');
        for (final item in arr) {
          encodeListItemValue(item, writer, depth + 2, options);
        }
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

  for (int i = 1; i < keys.length; i++) {
    final key = keys[i];
    encodeKeyValuePair(key, obj[key], writer, depth + 1, options);
  }
}

// #endregion

// #region List item encoding helpers

void encodeListItemValue(
  JsonValue value,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  if (isJsonPrimitive(value)) {
    writer.pushListItem(depth, encodePrimitive(value, options.delimiter));
  } else if (isJsonArray(value)) {
    final arr = value as JsonArray;
    if (isArrayOfPrimitives(arr)) {
      final inline = encodeInlineArrayLine(arr, options.delimiter, null);
      writer.pushListItem(depth, inline);
    } else {
      final header = formatHeader(arr.length, delimiter: options.delimiter);
      writer.pushListItem(depth, header);
      for (final item in arr) {
        encodeListItemValue(item, writer, depth + 1, options);
      }
    }
  } else if (isJsonObject(value)) {
    encodeObjectAsListItem(value as JsonObject, writer, depth, options);
  }
}

// #endregion
