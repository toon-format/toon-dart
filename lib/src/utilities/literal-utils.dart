import '../utilities/constants.dart';

/// Checks if a token is a boolean or null literal (`true`, `false`, `null`).
bool isBooleanOrNullLiteral(String token) {
  return token == trueLiteral || token == falseLiteral || token == nullLiteral;
}

/// Checks if a token represents a valid numeric literal.
///
/// Rejects numbers with leading zeros (except `"0"` itself or decimals like `"0.5"`).
bool isNumericLiteral(String token) {
  if (token.isEmpty) return false;

  // Must not have leading zeros (except for `"0"` itself or decimals like `"0.5"`)
  if (token.length > 1 && token[0] == '0' && token[1] != '.') {
    return false;
  }

  // Check if it's a valid number
  final numericValue = double.tryParse(token);
  return numericValue != null && numericValue.isFinite;
}
