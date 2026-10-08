import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string_utils.dart';
import '../utilities/validation.dart';

String encodePrimitive(JsonPrimitive value, String delimiter) {
  return switch (value) {
    String() => encodeStringLiteral(value, delimiter),
    num() => _encodeNumber(value),
    _ => '$value', // null, true, or false
  };
}

String _encodeNumber(num value) {
  // Dart prints the shortest round-trip digits, with a `.0` suffix on
  // integral doubles.
  final text = '$value';
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

String encodeStringLiteral(String value, String delimiter) {
  return isSafeUnquoted(value, delimiter) ? value : quoteString(value);
}

String encodeKey(String key) {
  return isValidUnquotedKey(key) ? key : quoteString(key);
}

String quoteString(String value) {
  return '$doubleQuote${escapeString(value)}$doubleQuote';
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
  final encodedKey = key == null ? '' : encodeKey(key);
  final keyedMarker = keyed ? colon : '';
  final delimiterSuffix = delimiter == defaultDelimiter ? '' : delimiter;
  final fieldGroup = fields == null ? '' : _formatFieldGroup(fields, delimiter);
  return '$encodedKey[$length$keyedMarker$delimiterSuffix]$fieldGroup:';
}

String _formatFieldGroup(List<FieldNode> fields, String delimiter) {
  final entries = [
    for (final field in fields)
      if (field.children case final children?)
        '${encodeKey(field.name)}${_formatFieldGroup(children, delimiter)}'
      else
        encodeKey(field.name),
  ];
  return '{${entries.join(delimiter)}}';
}
