import '../utilities/constants.dart';
import 'literal_utils.dart';

bool isValidUnquotedKey(String key) {
  // A letter or underscore, then letters, digits, underscores, or dots.
  return RegExp(r'^[A-Z_][\w.]*$', caseSensitive: false).hasMatch(key);
}

bool isSafeUnquoted(String value, [String delimiter = comma]) {
  if (value.isEmpty) {
    return false;
  }

  if (value != value.trim()) {
    return false;
  }

  if (isBooleanOrNullLiteral(value) || _isNumericLike(value)) {
    return false;
  }

  if (value.contains(':')) {
    return false;
  }

  if (value.contains('"') || value.contains('\\')) {
    return false;
  }

  if (RegExp(r'[[\]{}]').hasMatch(value)) {
    return false;
  }

  if (RegExp(r'[\n\r\t]').hasMatch(value)) {
    return false;
  }

  if (value.contains(delimiter)) {
    return false;
  }

  if (value.startsWith(listItemMarker)) {
    return false;
  }

  if (value.startsWith(commentMarker)) {
    return false;
  }

  return true;
}

bool _isNumericLike(String value) => RegExp(
  r'^[+-]?\d+(?:\.\d+)?(?:e[+-]?\d+)?$',
  caseSensitive: false,
).hasMatch(value);
