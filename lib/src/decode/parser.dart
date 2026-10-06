import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/literal-utils.dart';
import '../utilities/string-utils.dart';

// #region Array header parsing

ArrayHeaderParseResult? parseArrayHeaderLine(
  String content,
  String defaultDelimiter,
) {
  final trimmed = content.trimLeft();

  int bracketStart = -1;

  // A quoted key may contain brackets, so search after its closing quote.
  if (trimmed.startsWith(doubleQuote)) {
    final closingQuoteIndex = findClosingQuote(trimmed, 0);
    if (closingQuoteIndex == -1) {
      return null;
    }

    final afterQuote = trimmed.substring(closingQuoteIndex + 1);
    if (!afterQuote.startsWith(openBracket)) {
      return null;
    }

    final leadingWhitespace = content.length - trimmed.length;
    final keyEndIndex = leadingWhitespace + closingQuoteIndex + 1;
    bracketStart = content.indexOf(openBracket, keyEndIndex);
  } else {
    bracketStart = content.indexOf(openBracket);
  }

  if (bracketStart == -1) {
    return null;
  }

  final bracketEnd = content.indexOf(closeBracket, bracketStart);
  if (bracketEnd == -1) {
    return null;
  }

  int colonIndex = bracketEnd + 1;
  int braceEnd = colonIndex;

  final braceStart = content.indexOf(openBrace, bracketEnd);
  if (braceStart != -1 && braceStart < content.indexOf(colon, bracketEnd)) {
    final foundBraceEnd = content.indexOf(closeBrace, braceStart);
    if (foundBraceEnd != -1) {
      braceEnd = foundBraceEnd + 1;
    }
  }

  colonIndex = content.indexOf(
    colon,
    bracketEnd > braceEnd ? bracketEnd : braceEnd,
  );
  if (colonIndex == -1) {
    return null;
  }

  String? key;
  if (bracketStart > 0) {
    final rawKey = content.substring(0, bracketStart).trim();
    key = rawKey.startsWith(doubleQuote) ? parseStringLiteral(rawKey) : rawKey;
  }

  final afterColon = content.substring(colonIndex + 1).trim();

  final bracketContent = content.substring(bracketStart + 1, bracketEnd);

  BracketSegmentResult parsedBracket;
  try {
    parsedBracket = parseBracketSegment(bracketContent, defaultDelimiter);
  } catch (e) {
    return null;
  }

  final length = parsedBracket.length;
  final delimiter = parsedBracket.delimiter;

  List<String>? fields;
  if (braceStart != -1 && braceStart < colonIndex) {
    final foundBraceEnd = content.indexOf(closeBrace, braceStart);
    if (foundBraceEnd != -1 && foundBraceEnd < colonIndex) {
      final fieldsContent = content.substring(braceStart + 1, foundBraceEnd);
      fields = parseDelimitedValues(
        fieldsContent,
        delimiter,
      ).map((field) => parseStringLiteral(field.trim())).toList();
    }
  }

  return ArrayHeaderParseResult(
    header: ArrayHeaderInfo(
      key: key,
      length: length,
      delimiter: delimiter,
      fields: fields,
    ),
    inlineValues: afterColon.isEmpty ? null : afterColon,
  );
}

BracketSegmentResult parseBracketSegment(String seg, String defaultDelimiter) {
  String content = seg;

  String delimiter = defaultDelimiter;
  if (content.endsWith(tab)) {
    delimiter = tab;
    content = content.substring(0, content.length - 1);
  } else if (content.endsWith(pipe)) {
    delimiter = pipe;
    content = content.substring(0, content.length - 1);
  }

  final length = int.tryParse(content);
  if (length == null) {
    throw FormatException('Invalid array length: $seg');
  }

  return BracketSegmentResult(length: length, delimiter: delimiter);
}

// #endregion

// #region Delimited value parsing

List<String> parseDelimitedValues(String input, String delimiter) {
  final values = <String>[];
  final current = StringBuffer();
  bool inQuotes = false;
  int i = 0;

  while (i < input.length) {
    final char = input[i];

    if (char == backslash && i + 1 < input.length && inQuotes) {
      current.write(char);
      current.write(input[i + 1]);
      i += 2;
      continue;
    }

    if (char == doubleQuote) {
      inQuotes = !inQuotes;
      current.write(char);
      i++;
      continue;
    }

    if (char == delimiter && !inQuotes) {
      values.add(current.toString().trim());
      current.clear();
      i++;
      continue;
    }

    current.write(char);
    i++;
  }

  if (current.isNotEmpty || values.isNotEmpty) {
    values.add(current.toString().trim());
  }

  return values;
}

List<JsonPrimitive> mapRowValuesToPrimitives(List<String> values) {
  return values.map((v) => parsePrimitiveToken(v)).toList();
}

// #endregion

// #region Primitive and key parsing

JsonPrimitive parsePrimitiveToken(String token) {
  final trimmed = token.trim();

  if (trimmed.isEmpty) {
    return '';
  }

  if (trimmed.startsWith(doubleQuote)) {
    return parseStringLiteral(trimmed);
  }

  if (isBooleanOrNullLiteral(trimmed)) {
    if (trimmed == trueLiteral) return true;
    if (trimmed == falseLiteral) return false;
    if (trimmed == nullLiteral) return null;
  }

  if (isNumericLiteral(trimmed)) {
    final parsedNumber = double.parse(trimmed);
    return parsedNumber == -0.0 ? 0 : parsedNumber;
  }

  return trimmed;
}

String parseStringLiteral(String token) {
  final trimmedToken = token.trim();

  if (trimmedToken.startsWith(doubleQuote)) {
    final closingQuoteIndex = findClosingQuote(trimmedToken, 0);

    if (closingQuoteIndex == -1) {
      throw FormatException('Unterminated string: missing closing quote');
    }

    if (closingQuoteIndex != trimmedToken.length - 1) {
      throw FormatException('Unexpected characters after closing quote');
    }

    final content = trimmedToken.substring(1, closingQuoteIndex);
    return unescapeString(content);
  }

  return trimmedToken;
}

KeyTokenResult parseUnquotedKey(String content, int start) {
  int end = start;
  while (end < content.length && content[end] != colon) {
    end++;
  }

  if (end >= content.length || content[end] != colon) {
    throw FormatException('Missing colon after key');
  }

  final key = content.substring(start, end).trim();

  end++;

  return KeyTokenResult(key: key, end: end);
}

KeyTokenResult parseQuotedKey(String content, int start) {
  final closingQuoteIndex = findClosingQuote(content, start);

  if (closingQuoteIndex == -1) {
    throw FormatException('Unterminated quoted key');
  }

  final keyContent = content.substring(start + 1, closingQuoteIndex);
  final key = unescapeString(keyContent);
  int end = closingQuoteIndex + 1;

  if (end >= content.length || content[end] != colon) {
    throw FormatException('Missing colon after key');
  }
  end++;

  return KeyTokenResult(key: key, end: end);
}

KeyTokenResult parseKeyToken(String content, int start) {
  if (content[start] == doubleQuote) {
    return parseQuotedKey(content, start);
  } else {
    return parseUnquotedKey(content, start);
  }
}

// #endregion

// #region Array content detection helpers

bool isArrayHeaderAfterHyphen(String content) {
  return content.trim().startsWith(openBracket) &&
      findUnquotedChar(content, colon) != -1;
}

bool isObjectFirstFieldAfterHyphen(String content) {
  return findUnquotedChar(content, colon) != -1;
}

// #endregion
