import '../utilities/constants.dart';

/// Trims surrounding U+0020 spaces only: other whitespace, such as NBSP or a
/// tab outside its delimiter role, belongs to the token.
String trimSpaces(String value) {
  var start = 0;
  var end = value.length;
  while (start < end && value.codeUnitAt(start) == 0x20) {
    start++;
  }
  while (end > start && value.codeUnitAt(end - 1) == 0x20) {
    end--;
  }
  return value.substring(start, end);
}

String escapeString(String value) {
  return value
      .replaceAll(backslash, '$backslash$backslash')
      .replaceAll(doubleQuote, '$backslash$doubleQuote')
      .replaceAll(newline, '${backslash}n')
      .replaceAll(carriageReturn, '${backslash}r')
      .replaceAll(tab, '${backslash}t')
      .replaceAllMapped(
        RegExp(r'[\x00-\x1F]'),
        (m) =>
            '${backslash}u${m[0]!.codeUnitAt(0).toRadixString(16).padLeft(4, '0')}',
      );
}

final _fourHexDigits = RegExp(r'^[0-9a-fA-F]{4}$');

String unescapeString(String value) {
  final result = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    if (value[i] != backslash) {
      result.write(value[i]);
      continue;
    }
    if (i + 1 >= value.length) {
      throw const FormatException(
        'Invalid escape sequence: backslash at end of string',
      );
    }

    final next = value[++i];
    switch (next) {
      case 'n':
        result.write(newline);
      case 't':
        result.write(tab);
      case 'r':
        result.write(carriageReturn);
      case backslash || doubleQuote:
        result.write(next);
      case 'u':
        final hex = value.length >= i + 5 ? value.substring(i + 1, i + 5) : '';
        if (!_fourHexDigits.hasMatch(hex)) {
          throw const FormatException(
            'Invalid escape sequence: \\u must be followed by 4 hex digits',
          );
        }
        final codeUnit = int.parse(hex, radix: 16);
        // Supplementary code points must appear as literal UTF-8.
        if (codeUnit >= 0xD800 && codeUnit <= 0xDFFF) {
          throw FormatException(
            'Invalid escape sequence: \\u$hex is a lone surrogate',
          );
        }
        result.writeCharCode(codeUnit);
        i += 4;
      default:
        throw FormatException('Invalid escape sequence: \\$next');
    }
  }
  return result.toString();
}

/// Returns the index of the quote closing the one at [start], skipping escaped
/// characters, or -1.
int findClosingQuote(String content, int start) {
  int i = start + 1;
  while (i < content.length) {
    if (content[i] == backslash && i + 1 < content.length) {
      i += 2;
      continue;
    }
    if (content[i] == doubleQuote) {
      return i;
    }
    i++;
  }
  return -1;
}

/// Returns the index of the first [char] outside quotes from [start] on, or -1.
int findUnquotedChar(String content, String char, [int start = 0]) {
  bool inQuotes = false;
  int i = start;

  while (i < content.length) {
    if (content[i] == backslash && i + 1 < content.length && inQuotes) {
      i += 2;
      continue;
    }

    if (content[i] == doubleQuote) {
      inQuotes = !inQuotes;
      i++;
      continue;
    }

    if (content[i] == char && !inQuotes) {
      return i;
    }

    i++;
  }

  return -1;
}
