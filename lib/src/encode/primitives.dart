import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string-utils.dart';
import '../utilities/validation.dart';

// #region Primitive encoding

/// Encodes a primitive value to a string.
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

/// Encodes a string literal, adding quotes if necessary.
String encodeStringLiteral(String value, [String delimiter = comma]) {
  if (isSafeUnquoted(value, delimiter)) {
    return value;
  }

  return '$doubleQuote${escapeString(value)}$doubleQuote';
}

// #endregion

// #region Key encoding

/// Encodes a key, adding quotes if necessary.
String encodeKey(String key) {
  if (isValidUnquotedKey(key)) {
    return key;
  }

  return '$doubleQuote${escapeString(key)}$doubleQuote';
}

// #endregion

// #region Value joining

/// Encodes and joins primitive values with a delimiter.
String encodeAndJoinPrimitives(List<JsonPrimitive> values,
    [String delimiter = comma]) {
  return values.map((v) => encodePrimitive(v, delimiter)).join(delimiter);
}

// #endregion

// #region Header formatters

/// Formats an array header.
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

  // Only include delimiter if it's not the default (comma)
  final delimiterSuffix =
      delimiterValue != defaultDelimiter ? delimiterValue : '';
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
