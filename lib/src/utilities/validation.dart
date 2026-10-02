import '../utilities/constants.dart';
import 'literal-utils.dart';

/// Checks if a key can be used without quotes.
///
/// Valid unquoted keys must start with a letter or underscore,
/// followed by letters, digits, underscores, or dots.
bool isValidUnquotedKey(String key) {
  return RegExp(r'^[A-Z_][\w.]*$', caseSensitive: false).hasMatch(key);
}

/// Determines if a string value can be safely encoded without quotes.
///
/// A string needs quoting if it:
/// - Is empty
/// - Has leading or trailing whitespace
/// - Could be confused with a literal (boolean, null, number)
/// - Contains structural characters (colons, brackets, braces)
/// - Contains quotes or backslashes (need escaping)
/// - Contains control characters (newlines, tabs, etc.)
/// - Contains the active delimiter
/// - Starts with a list marker (hyphen)
bool isSafeUnquoted(String value, [String delimiter = comma]) {
  if (value.isEmpty) {
    return false;
  }

  if (value != value.trim()) {
    return false;
  }

  // Check if it looks like any literal value (boolean, null, or numeric)
  if (isBooleanOrNullLiteral(value) || isNumericLike(value)) {
    return false;
  }

  // Check for colon (always structural)
  if (value.contains(':')) {
    return false;
  }

  // Check for quotes and backslash (always need escaping)
  if (value.contains('"') || value.contains('\\')) {
    return false;
  }

  // Check for brackets and braces (always structural)
  if (RegExp(r'[[\]{}]').hasMatch(value)) {
    return false;
  }

  // Check for control characters (newline, carriage return, tab - always need quoting/escaping)
  if (RegExp(r'[\n\r\t]').hasMatch(value)) {
    return false;
  }

  // Check for the active delimiter
  if (value.contains(delimiter)) {
    return false;
  }

  // Check for hyphen at start (list marker)
  if (value.startsWith(listItemMarker)) {
    return false;
  }

  return true;
}

/// Checks if a string looks like a number.
///
/// Match numbers like `42`, `-3.14`, `1e-6`, `05`, etc.
bool isNumericLike(String value) {
  return RegExp(r'^-?\d+(?:\.\d+)?(?:e[+-]?\d+)?$', caseSensitive: false).hasMatch(value) ||
      RegExp(r'^0\d+$').hasMatch(value);
}
