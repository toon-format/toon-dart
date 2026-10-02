/// Type definitions for TOON format encoding and decoding.

/// JSON primitive types (string, number, boolean, null).
typedef JsonPrimitive = Object?; // null, String, num, bool

/// JSON array type.
typedef JsonArray = List<JsonValue>;

/// JSON object type.
typedef JsonObject = Map<String, JsonValue>;

/// JSON value type (primitive, array, or object).
typedef JsonValue = Object?; // JsonPrimitive | JsonArray | JsonObject

/// Parsed line information.
class ParsedLine {
  final String raw;
  final int indent;
  final String content;
  final int depth;
  final int lineNumber;

  const ParsedLine({
    required this.raw,
    required this.indent,
    required this.content,
    required this.depth,
    required this.lineNumber,
  });
}

/// Blank line information.
class BlankLineInfo {
  final int lineNumber;
  final int indent;
  final int depth;

  const BlankLineInfo({
    required this.lineNumber,
    required this.indent,
    required this.depth,
  });
}

/// Array header information.
class ArrayHeaderInfo {
  final String? key;
  final int length;
  final String delimiter;
  final List<String>? fields;

  const ArrayHeaderInfo({
    this.key,
    required this.length,
    required this.delimiter,
    this.fields,
  });
}

/// Result of parsing an array header line.
class ArrayHeaderParseResult {
  final ArrayHeaderInfo header;
  final String? inlineValues;

  const ArrayHeaderParseResult({
    required this.header,
    this.inlineValues,
  });
}

/// Result of parsing a bracket segment.
class BracketSegmentResult {
  final int length;
  final String delimiter;

  const BracketSegmentResult({
    required this.length,
    required this.delimiter,
  });
}

/// Result of parsing a key token.
class KeyTokenResult {
  final String key;
  final int end;

  const KeyTokenResult({
    required this.key,
    required this.end,
  });
}

/// Result of decoding a key-value pair.
class KeyValueResult {
  final String key;
  final JsonValue value;
  final int followDepth;

  const KeyValueResult({
    required this.key,
    required this.value,
    required this.followDepth,
  });
}

/// Result of decoding a key-value pair (simple version).
class KeyValuePairResult {
  final String key;
  final JsonValue value;

  const KeyValuePairResult({
    required this.key,
    required this.value,
  });
}

