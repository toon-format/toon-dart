import '../options.dart';
import '../types.dart';
import '../utilities/constants.dart';
import 'normalize.dart';
import 'primitives.dart';
import 'tabular.dart';
import 'writer.dart';

String encodeValue(JsonValue value, EncodeOptions options) {
  if (value is! JsonArray && value is! JsonObject) {
    // Unquoted, a leading U+FEFF would be read as the document's byte-order
    // mark and stripped on decode.
    return value is String && value.startsWith(byteOrderMark)
        ? quoteString(value)
        : encodePrimitive(value, options.delimiter.symbol);
  }

  final writer = LineWriter(options.indentSize);
  switch (value) {
    case JsonArray():
      encodeArray(null, value, writer, 0, options);
    case JsonObject():
      encodeObjectValue(null, value, writer, 0, options);
  }
  return writer.toString();
}

void encodeObject(
  JsonObject value,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  for (final MapEntry(:key, :value) in value.entries) {
    encodeKeyValuePair(key, value, writer, depth, options);
  }
}

void encodeKeyValuePair(
  String key,
  JsonValue value,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  switch (value) {
    case JsonArray():
      encodeArray(key, value, writer, depth, options);
    case JsonObject():
      encodeObjectValue(key, value, writer, depth, options);
    default:
      writer.push(
        depth,
        '${encodeKey(key)}: ${encodePrimitive(value, options.delimiter.symbol)}',
      );
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
      delimiter: options.delimiter.symbol,
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
      '${encodeKey(key)}: ${encodeAndJoinPrimitives(leaves, options.delimiter.symbol)}',
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
    writer.push(
      depth,
      encodeInlineArrayLine(value, options.delimiter.symbol, key),
    );
    return;
  }

  if (isArrayOfObjects(value)) {
    final rows = value.cast<JsonObject>();
    final fields = extractTabularFields(rows);
    if (fields != null) {
      encodeArrayOfObjectsAsTabular(key, rows, fields, writer, depth, options);
      return;
    }
  }

  encodeMixedArrayAsListItems(key, value, writer, depth, options);
}

String encodeInlineArrayLine(
  List<JsonPrimitive> values,
  String delimiter,
  String? key,
) {
  final header = formatHeader(values.length, key: key, delimiter: delimiter);
  if (values.isEmpty) {
    return header;
  }
  return '$header ${encodeAndJoinPrimitives(values, delimiter)}';
}

void encodeArrayOfObjectsAsTabular(
  String? key,
  List<JsonObject> rows,
  List<FieldNode> fields,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  final header = formatHeader(
    rows.length,
    key: key,
    fields: fields,
    delimiter: options.delimiter.symbol,
  );
  writer.push(depth, header);
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
    writer.push(
      depth,
      encodeAndJoinPrimitives(leaves, options.delimiter.symbol),
    );
  }
}

void encodeMixedArrayAsListItems(
  String? key,
  JsonArray items,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  final header = formatHeader(
    items.length,
    key: key,
    delimiter: options.delimiter.symbol,
  );
  writer.push(depth, header);
  for (final item in items) {
    encodeListItemValue(item, writer, depth + 1, options);
  }
}

void encodeListItemValue(
  JsonValue value,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  switch (value) {
    case JsonArray() when isArrayOfPrimitives(value):
      writer.pushListItem(
        depth,
        encodeInlineArrayLine(value, options.delimiter.symbol, null),
      );
    case JsonArray():
      writer.pushListItem(
        depth,
        formatHeader(value.length, delimiter: options.delimiter.symbol),
      );
      for (final item in value) {
        encodeListItemValue(item, writer, depth + 1, options);
      }
    case JsonObject():
      encodeObjectAsListItem(value, writer, depth, options);
    default:
      writer.pushListItem(
        depth,
        encodePrimitive(value, options.delimiter.symbol),
      );
  }
}

/// Puts the first field on the hyphen line; its nested lines sit at
/// `depth + 2`, the remaining fields at `depth + 1`.
void encodeObjectAsListItem(
  JsonObject obj,
  LineWriter writer,
  int depth,
  EncodeOptions options,
) {
  if (obj.isEmpty) {
    writer.push(depth, listItemMarker);
    return;
  }

  final MapEntry(key: firstKey, value: firstValue) = obj.entries.first;
  final encodedKey = encodeKey(firstKey);

  switch (firstValue) {
    case JsonArray() when firstValue.isEmpty:
      writer.pushListItem(depth, '$encodedKey: []');
    case JsonArray() when isArrayOfPrimitives(firstValue):
      writer.pushListItem(
        depth,
        encodeInlineArrayLine(firstValue, options.delimiter.symbol, firstKey),
      );
    case JsonArray():
      final rows = isArrayOfObjects(firstValue)
          ? firstValue.cast<JsonObject>()
          : null;
      final fields = rows == null ? null : extractTabularFields(rows);
      if (rows != null && fields != null) {
        final header = formatHeader(
          rows.length,
          key: firstKey,
          fields: fields,
          delimiter: options.delimiter.symbol,
        );
        writer.pushListItem(depth, header);
        writeTabularRows(rows, fields, writer, depth + 2, options);
      } else {
        final header = formatHeader(
          firstValue.length,
          key: firstKey,
          delimiter: options.delimiter.symbol,
        );
        writer.pushListItem(depth, header);
        for (final item in firstValue) {
          encodeListItemValue(item, writer, depth + 2, options);
        }
      }
    case JsonObject():
      final keyedFields = extractKeyedTabularFields(firstValue);
      if (keyedFields != null) {
        final header = formatHeader(
          firstValue.length,
          key: firstKey,
          fields: keyedFields,
          delimiter: options.delimiter.symbol,
          keyed: true,
        );
        writer.pushListItem(depth, header);
        writeKeyedEntryRows(
          firstValue,
          keyedFields,
          writer,
          depth + 2,
          options,
        );
      } else {
        writer.pushListItem(depth, '$encodedKey:');
        encodeObject(firstValue, writer, depth + 2, options);
      }
    default:
      writer.pushListItem(
        depth,
        '$encodedKey: ${encodePrimitive(firstValue, options.delimiter.symbol)}',
      );
  }

  for (final MapEntry(:key, :value) in obj.entries.skip(1)) {
    encodeKeyValuePair(key, value, writer, depth + 1, options);
  }
}
