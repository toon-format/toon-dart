import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string_utils.dart';
import '../utilities/validation.dart';

// #region Primitive encoding

String encodePrimitive(JsonPrimitive value, [String? delimiter]) {
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

  return encodeStringLiteral(value as String, delimiter ?? comma);
}

String encodeStringLiteral(String value, [String delimiter = comma]) {
  if (isSafeUnquoted(value, delimiter)) {
    return value;
  }

  return '$doubleQuote${escapeString(value)}$doubleQuote';
}

// #endregion

// #region Key encoding

String encodeKey(String key) {
  if (isValidUnquotedKey(key)) {
    return key;
  }

  return '$doubleQuote${escapeString(key)}$doubleQuote';
}

// #endregion

// #region Value joining

String encodeAndJoinPrimitives(
  List<JsonPrimitive> values, [
  String delimiter = comma,
]) {
  return values.map((v) => encodePrimitive(v, delimiter)).join(delimiter);
}

// #endregion

// #region Header formatters

String formatHeader(
  int length, {
  String? key,
  List<FieldNode>? fields,
  String? delimiter,
}) {
  final delimiterValue = delimiter ?? comma;

  String header = '';

  if (key != null) {
    header += encodeKey(key);
  }

  final delimiterSuffix = delimiterValue != defaultDelimiter
      ? delimiterValue
      : '';
  header += '[$length$delimiterSuffix]';

  if (fields != null) {
    header += '{${_formatFieldSegment(fields, delimiterValue)}}';
  }

  header += ':';

  return header;
}

// #endregion

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
