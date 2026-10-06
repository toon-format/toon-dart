import '../utilities/constants.dart';

bool isBooleanOrNullLiteral(String token) {
  return token == trueLiteral || token == falseLiteral || token == nullLiteral;
}

bool isNumericLiteral(String token) {
  if (token.isEmpty) return false;

  // Leading zeros make a string, except in `0` itself and decimals like `0.5`.
  if (token.length > 1 && token[0] == '0' && token[1] != '.') {
    return false;
  }

  final numericValue = double.tryParse(token);
  return numericValue != null && numericValue.isFinite;
}
