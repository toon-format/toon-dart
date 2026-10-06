import 'constants.dart';

final _numericLiteral = RegExp(
  r'^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:e[+-]?\d+)?$',
  caseSensitive: false,
);

bool isBooleanOrNullLiteral(String token) {
  return token == trueLiteral || token == falseLiteral || token == nullLiteral;
}

/// Returns the value of the number [token], or null when it is no number or
/// overflows to infinity.
double? parseNumericLiteral(String token) {
  if (!_numericLiteral.hasMatch(token)) return null;
  final value = double.parse(token);
  if (!value.isFinite) return null;
  // `-0.0 == 0`, so this also folds -0 into 0.
  return value == 0 ? 0.0 : value;
}
