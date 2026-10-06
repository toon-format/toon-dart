import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string_utils.dart';
import '../utilities/validation.dart';

String encodePrimitive(JsonPrimitive value, String delimiter) {
  if (value == null) {
    return nullLiteral;
  }

  if (value is bool) {
    return value.toString();
  }

  if (value is num) {
    // Dart prints the shortest round-trip digits, with a `.0` suffix on
    // integral doubles.
    final text = value.toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  return encodeStringLiteral(value as String, delimiter);
}

String encodeStringLiteral(String value, String delimiter) {
  if (isSafeUnquoted(value, delimiter)) {
    return value;
  }

  return '$doubleQuote${escapeString(value)}$doubleQuote';
}

String encodeKey(String key) {
  if (isValidUnquotedKey(key)) {
    return key;
  }

  return '$doubleQuote${escapeString(key)}$doubleQuote';
}

String encodeAndJoinPrimitives(List<JsonPrimitive> values, String delimiter) {
  return values.map((v) => encodePrimitive(v, delimiter)).join(delimiter);
}

String formatHeader(
  int length, {
  String? key,
  List<FieldNode>? fields,
  required String delimiter,
  bool keyed = false,
}) {
  String header = '';

  if (key != null) {
    header += encodeKey(key);
  }

  final delimiterSuffix = delimiter != defaultDelimiter ? delimiter : '';
  header += '[$length${keyed ? colon : ''}$delimiterSuffix]';

  if (fields != null) {
    header += '{${_formatFieldSegment(fields, delimiter)}}';
  }

  header += ':';

  return header;
}

String _formatFieldSegment(List<FieldNode> fields, String delimiter) {
  return fields
      .map(
        (field) =>
            encodeKey(field.name) +
            (field.children == null
                ? ''
                : '{${_formatFieldSegment(field.children!, delimiter)}}'),
      )
      .join(delimiter);
}
