import 'constants.dart';
import 'literal_utils.dart';

final _unquotedKey = RegExp(r'^[A-Z_][\w.]*$', caseSensitive: false);
final _numericLike = RegExp(
  r'^[+-]?\d+(?:\.\d+)?(?:e[+-]?\d+)?$',
  caseSensitive: false,
);
// Only space and tab: Dart's trim() also strips Unicode whitespace that
// decoders keep.
final _edgeWhitespace = RegExp(r'^[ \t]|[ \t]$');
final _structuralChar = RegExp(r'[:"\\\[\]{}\x00-\x1F]');

bool isValidUnquotedKey(String key) => _unquotedKey.hasMatch(key);

bool isSafeUnquoted(String value, String delimiter) {
  return value.isNotEmpty &&
      !_edgeWhitespace.hasMatch(value) &&
      !isBooleanOrNullLiteral(value) &&
      !_numericLike.hasMatch(value) &&
      !_structuralChar.hasMatch(value) &&
      !value.contains(delimiter) &&
      !value.startsWith(listItemMarker) &&
      !value.startsWith(commentMarker);
}
