import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string-utils.dart';
import '../utilities/validation.dart';

// #region Primitive encoding

String encodePrimitive(JsonPrimitive value, [String? delimiter]) {
  if (value == null) {
    return nullLiteral;
  }

  if (value is bool) {
    return value.toString();
  }

  if (value is double && value == value.truncateToDouble()) {
    return value.toStringAsFixed(0);
  }
  if (value is num) {
    return value.toString();
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
  List<String>? fields,
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
    final quotedFields = fields.map((f) => encodeKey(f)).toList();
    final joinedFields = quotedFields.join(delimiterValue);
    header += '{$joinedFields}';
  }

  header += ':';

  return header;
}

// #endregion
