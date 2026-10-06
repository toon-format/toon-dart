import '../utilities/constants.dart';

String escapeString(String value) {
  return value
      .replaceAll(backslash, '$backslash$backslash')
      .replaceAll(doubleQuote, '$backslash$doubleQuote')
      .replaceAll(newline, '${backslash}n')
      .replaceAll(carriageReturn, '${backslash}r')
      .replaceAll(tab, '${backslash}t');
}

String unescapeString(String value) {
  final result = StringBuffer();
  int i = 0;

  while (i < value.length) {
    if (value[i] == backslash) {
      if (i + 1 >= value.length) {
        throw FormatException(
          'Invalid escape sequence: backslash at end of string',
        );
      }

      final next = value[i + 1];
      if (next == 'n') {
        result.write(newline);
        i += 2;
        continue;
      }
      if (next == 't') {
        result.write(tab);
        i += 2;
        continue;
      }
      if (next == 'r') {
        result.write(carriageReturn);
        i += 2;
        continue;
      }
      if (next == backslash) {
        result.write(backslash);
        i += 2;
        continue;
      }
      if (next == doubleQuote) {
        result.write(doubleQuote);
        i += 2;
        continue;
      }

      throw FormatException('Invalid escape sequence: \\$next');
    }

    result.write(value[i]);
    i++;
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
