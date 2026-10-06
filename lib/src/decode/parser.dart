import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/literal_utils.dart';
import '../utilities/string_utils.dart';

/// Parses [content] as an array header, or returns null when it is no header
/// line. An invalid header throws in strict mode and falls through to a
/// key-value line in non-strict mode.
ArrayHeaderParseResult? resolveArrayHeader(String content, bool strict) {
  final ArrayHeaderParseResult? result;
  try {
    result = parseArrayHeaderLine(content);
  } on FormatException {
    if (strict) rethrow;
    return null;
  }

  // Non-strict mode resolves duplicate field names by last-write-wins.
  if (result?.header.fields case final fields? when strict) {
    _assertUniqueFieldNames(fields);
  }
  return result;
}

void _assertUniqueFieldNames(List<FieldNode> fields) {
  final seen = <String>{};
  for (final field in fields) {
    if (!seen.add(field.name)) {
      throw FormatException(
        'Duplicate field name "${field.name}" in field list',
      );
    }
    if (field.children case final children?) _assertUniqueFieldNames(children);
  }
}

/// Returns null when [content] is no header line and throws a
/// [FormatException] when it is an invalid one.
ArrayHeaderParseResult? parseArrayHeaderLine(String content) {
  final bracketStart = findUnquotedChar(content, openBracket);
  if (bracketStart == -1) {
    return null;
  }

  // A header needs a colon, and its key can't contain one.
  final firstColonIndex = findUnquotedChar(content, colon);
  if (firstColonIndex == -1 || firstColonIndex < bracketStart) {
    return null;
  }

  // Past this check, a grammar failure makes the line an invalid header
  // instead of a key-value line.
  final bracketEnd = findUnquotedChar(content, closeBracket, bracketStart);
  if (bracketEnd == -1) {
    throw const FormatException('Unterminated bracket segment');
  }

  var headerEnd = bracketEnd + 1;
  String? fieldsContent;
  final braceStart = findUnquotedChar(content, openBrace, bracketEnd);
  if (braceStart != -1 &&
      braceStart < findUnquotedChar(content, colon, bracketEnd)) {
    _assertNoGap(content, bracketEnd + 1, braceStart, 'field list');
    final braceEnd = findMatchingBrace(content, braceStart);
    if (braceEnd == -1) {
      throw const FormatException('Unmatched brace in field list');
    }
    fieldsContent = content.substring(braceStart + 1, braceEnd);
    headerEnd = braceEnd + 1;
  }

  final colonIndex = findUnquotedChar(content, colon, headerEnd);
  if (colonIndex == -1) {
    throw const FormatException('Missing colon after array header');
  }
  _assertNoGap(content, headerEnd, colonIndex, 'colon');

  String? key;
  if (bracketStart > 0) {
    final rawKey = content.substring(0, bracketStart);
    // Trimming would silently turn `foo [2]:` into a header with key `foo`.
    if (rawKey != rawKey.trimRight()) {
      throw const FormatException(
        'Unexpected whitespace between key and bracket segment',
      );
    }
    key = rawKey.startsWith(doubleQuote) ? parseStringLiteral(rawKey) : rawKey;
  }

  final afterColon = trimSpaces(content.substring(colonIndex + 1));

  final bracketContent = content.substring(bracketStart + 1, bracketEnd);

  final (:length, :delimiter, :keyed) = parseBracketSegment(bracketContent);

  List<FieldNode>? fields;
  if (fieldsContent != null) {
    for (final other in const [comma, tab, pipe]) {
      if (other != delimiter && findUnquotedChar(fieldsContent, other) != -1) {
        throw FormatException(
          'Header delimiter mismatch: field list contains unquoted "${escapeString(other)}"',
        );
      }
    }
    fields = parseFieldEntries(fieldsContent, delimiter);
  }

  if (keyed && fields == null) {
    throw const FormatException('Keyed header requires a field list');
  }

  // Decoding the values as an inline array would silently drop the fields.
  if (fields != null && afterColon.isNotEmpty) {
    throw const FormatException(
      'Unexpected content after fields-bearing header colon',
    );
  }

  return (
    header: ArrayHeaderInfo(
      key: key,
      length: length,
      delimiter: delimiter,
      fields: fields,
      keyed: keyed,
    ),
    inlineValues: afterColon.isEmpty ? null : afterColon,
  );
}

final _bracketLength = RegExp(r'^(?:0|[1-9]\d*)$');

({int length, String delimiter, bool keyed}) parseBracketSegment(
  String segment,
) {
  var content = segment;

  var delimiter = defaultDelimiter;
  if (content.endsWith(tab) || content.endsWith(pipe)) {
    delimiter = content[content.length - 1];
    content = content.substring(0, content.length - 1);
  }

  // Only a colon between the length and the delimiter symbol marks a keyed
  // header; anywhere else it fails the length check below.
  final keyed = content.endsWith(colon);
  if (keyed) {
    content = content.substring(0, content.length - 1);
  }

  if (!_bracketLength.hasMatch(content)) {
    throw FormatException('Invalid array length: "$segment"');
  }

  // A length beyond the int range can never match a count; -1 marks it for
  // the count error.
  return (
    length: int.tryParse(content) ?? -1,
    delimiter: delimiter,
    keyed: keyed,
  );
}

void _assertNoGap(String content, int start, int end, String target) {
  final gap = content.substring(start, end);
  if (gap.isNotEmpty) {
    throw FormatException(
      'Unexpected "$gap" between bracket segment and $target',
    );
  }
}

/// Parses a field list, descending into nested field groups
/// (`field{sub1,sub2}`).
List<FieldNode> parseFieldEntries(String content, String delimiter) {
  return [
    for (final entry in _splitFieldEntries(content, delimiter))
      _parseFieldEntry(trimSpaces(entry), delimiter),
  ];
}

FieldNode _parseFieldEntry(String entry, String delimiter) {
  if (entry.isEmpty) {
    throw const FormatException('Empty field name in field list');
  }

  final groupStart = findUnquotedChar(entry, openBrace);
  if (groupStart == -1) return FieldNode(parseStringLiteral(entry));

  final name = entry.substring(0, groupStart);
  if (name.isEmpty) {
    throw const FormatException('Missing field name before nested field group');
  }
  if (name != name.trimRight()) {
    throw const FormatException(
      'Unexpected whitespace before nested field group',
    );
  }
  final groupEnd = findMatchingBrace(entry, groupStart);
  if (groupEnd == -1) {
    throw const FormatException('Unmatched brace in field list');
  }
  if (groupEnd != entry.length - 1) {
    throw const FormatException('Unexpected content after nested field group');
  }

  return FieldNode(
    parseStringLiteral(name),
    parseFieldEntries(entry.substring(groupStart + 1, groupEnd), delimiter),
  );
}

/// Splits a field list on [delimiter] outside quotes and nested groups.
List<String> _splitFieldEntries(String content, String delimiter) {
  final entries = <String>[];
  var entryStart = 0;
  var inQuotes = false;
  var depth = 0;
  for (var i = 0; i < content.length; i++) {
    final char = content[i];
    if (char == backslash && inQuotes) {
      i++;
    } else if (char == doubleQuote) {
      inQuotes = !inQuotes;
    } else if (!inQuotes && char == openBrace) {
      depth++;
    } else if (!inQuotes && char == closeBrace) {
      depth--;
    } else if (!inQuotes && depth == 0 && char == delimiter) {
      entries.add(content.substring(entryStart, i));
      entryStart = i + 1;
    }
  }
  entries.add(content.substring(entryStart));
  return entries;
}

/// Counts the leaf fields of [fields]: the number of cells per row.
int countLeafFields(List<FieldNode> fields) {
  var count = 0;
  for (final field in fields) {
    count += switch (field.children) {
      final children? => countLeafFields(children),
      null => 1,
    };
  }
  return count;
}

/// Returns the index of the brace closing the one at [braceStart], ignoring
/// braces inside quoted names, or -1.
int findMatchingBrace(String content, int braceStart) {
  var inQuotes = false;
  var depth = 0;
  for (var i = braceStart; i < content.length; i++) {
    final char = content[i];
    if (char == backslash && inQuotes) {
      i++;
    } else if (char == doubleQuote) {
      inQuotes = !inQuotes;
    } else if (!inQuotes && char == openBrace) {
      depth++;
    } else if (!inQuotes && char == closeBrace && --depth == 0) {
      return i;
    }
  }
  return -1;
}

List<String> parseDelimitedValues(String input, String delimiter) {
  if (input.isEmpty) return [];

  final values = <String>[];
  var valueStart = 0;
  var inQuotes = false;
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == backslash && inQuotes) {
      i++;
    } else if (char == doubleQuote) {
      inQuotes = !inQuotes;
    } else if (!inQuotes && char == delimiter) {
      values.add(trimSpaces(input.substring(valueStart, i)));
      valueStart = i + 1;
    }
  }
  values.add(trimSpaces(input.substring(valueStart)));
  return values;
}

List<JsonPrimitive> mapRowValuesToPrimitives(List<String> values) {
  return values.map(parsePrimitiveToken).toList();
}

JsonPrimitive parsePrimitiveToken(String token) {
  final trimmed = trimSpaces(token);
  return switch (trimmed) {
    trueLiteral => true,
    falseLiteral => false,
    nullLiteral => null,
    _ when trimmed.startsWith(doubleQuote) => parseStringLiteral(trimmed),
    _ => parseNumericLiteral(trimmed) ?? trimmed,
  };
}

String parseStringLiteral(String token) {
  final trimmedToken = trimSpaces(token);

  if (trimmedToken.startsWith(doubleQuote)) {
    final closingQuoteIndex = findClosingQuote(trimmedToken, 0);

    if (closingQuoteIndex == -1) {
      throw const FormatException('Unterminated string: missing closing quote');
    }

    if (closingQuoteIndex != trimmedToken.length - 1) {
      throw const FormatException('Unexpected characters after closing quote');
    }

    final content = trimmedToken.substring(1, closingQuoteIndex);
    return unescapeString(content);
  }

  return trimmedToken;
}

/// Parses the key of the key-value line [content] and returns it with the
/// index after its colon.
({String key, int end}) parseKeyToken(String content) {
  return content.startsWith(doubleQuote)
      ? _parseQuotedKey(content)
      : _parseUnquotedKey(content);
}

({String key, int end}) _parseUnquotedKey(String content) {
  // A raw scan would cut `a "b:c" d: 1` at the quoted colon.
  final colonIndex = findUnquotedChar(content, colon);
  if (colonIndex == -1) {
    throw const FormatException('Missing colon after key');
  }

  return (
    key: trimSpaces(content.substring(0, colonIndex)),
    end: colonIndex + 1,
  );
}

({String key, int end}) _parseQuotedKey(String content) {
  final closingQuoteIndex = findClosingQuote(content, 0);

  if (closingQuoteIndex == -1) {
    throw const FormatException('Unterminated quoted key');
  }

  final key = unescapeString(content.substring(1, closingQuoteIndex));
  var end = closingQuoteIndex + 1;
  while (end < content.length && content[end] == space) {
    end++;
  }

  if (end >= content.length || content[end] != colon) {
    throw const FormatException('Missing colon after key');
  }
  end++;

  return (key: key, end: end);
}

bool isArrayHeaderContent(String content) {
  return trimSpaces(content).startsWith(openBracket) &&
      findUnquotedChar(content, colon) != -1;
}

bool isKeyValueContent(String content) {
  return findUnquotedChar(content, colon) != -1;
}
