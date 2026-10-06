import '../utilities/constants.dart';

final _numericLiteral = RegExp(
  r'^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:e[+-]?\d+)?$',
  caseSensitive: false,
);

bool isBooleanOrNullLiteral(String token) {
  return token == trueLiteral || token == falseLiteral || token == nullLiteral;
}

bool isNumericLiteral(String token) {
  return _numericLiteral.hasMatch(token) && double.parse(token).isFinite;
}
