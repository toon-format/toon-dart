import '../options.dart';
import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string_utils.dart';
import 'normalize.dart';
import 'primitives.dart';
import 'tabular.dart';
import 'writer.dart';

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
    encodeObjectValue(null, value as JsonObject, writer, 0, options);
  }

  return writer.toString();
}

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
    encodeObjectValue(key, value as JsonObject, writer, depth, options);
  }
}

/// Encodes an object value under [key], or at the root when [key] is null.
void encodeObjectValue(
  String? key,
  JsonObject value,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  final keyedFields = extractKeyedTabularFields(value);
  if (keyedFields != null) {
    final header = formatHeader(
      value.length,
      key: key,
      fields: keyedFields,
      delimiter: options.delimiter,
      keyed: true,
    );
    writer.push(depth, header);
    writeKeyedEntryRows(value, keyedFields, writer, depth + 1, options);
    return;
  }

  if (key == null) {
    encodeObject(value, writer, depth, options);
    return;
  }
  writer.push(depth, '${encodeKey(key)}:');
  encodeObject(value, writer, depth + 1, options);
}

void writeKeyedEntryRows(
  JsonObject value,
  List<FieldNode> fields,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  for (final MapEntry(:key, value: entry) in value.entries) {
    final leaves = collectRowLeaves(entry as JsonObject, fields);
    writer.push(
      depth,
      '${encodeKey(key)}: ${encodeAndJoinPrimitives(leaves, options.delimiter)}',
    );
  }
}

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

  if (isArrayOfObjects(value)) {
    final objects = value.cast<JsonObject>();
    final fields = extractTabularFields(objects);
    if (fields != null) {
      encodeArrayOfObjectsAsTabular(
        key,
        objects,
        fields,
        writer,
        depth,
        options,
      );
      return;
    }
  }

  encodeMixedArrayAsListItems(key, value, writer, depth, options);
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

void encodeArrayOfObjectsAsTabular(
  String? prefix,
  List<JsonObject> rows,
  List<FieldNode> fields,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  final formattedHeader = formatHeader(
    rows.length,
    key: prefix,
    fields: fields,
    delimiter: options.delimiter,
  );
  writer.push(depth, formattedHeader);

  writeTabularRows(rows, fields, writer, depth + 1, options);
}

void writeTabularRows(
  List<JsonObject> rows,
  List<FieldNode> fields,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  for (final row in rows) {
    final leaves = collectRowLeaves(row, fields);
    writer.push(depth, encodeAndJoinPrimitives(leaves, options.delimiter));
  }
}

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
      final fields = objects == null ? null : extractTabularFields(objects);
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
    final nested = firstValue as JsonObject;
    final keyedFields = extractKeyedTabularFields(nested);
    if (keyedFields != null) {
      final header = formatHeader(
        nested.length,
        key: firstKey,
        fields: keyedFields,
        delimiter: options.delimiter,
        keyed: true,
      );
      writer.pushListItem(depth, header);
      writeKeyedEntryRows(nested, keyedFields, writer, depth + 2, options);
    } else {
      writer.pushListItem(depth, '$encodedKey:');
      encodeObject(nested, writer, depth + 2, options);
    }
  }

  for (int i = 1; i < keys.length; i++) {
    final key = keys[i];
    encodeKeyValuePair(key, obj[key], writer, depth + 1, options);
  }
}

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
