typedef JsonPrimitive = Object?; // null, String, num, bool

typedef JsonArray = List<JsonValue>;

typedef JsonObject = Map<String, JsonValue>;

typedef JsonValue = Object?; // JsonPrimitive | JsonArray | JsonObject

/// One entry of a tabular field list: a leaf maps to one row cell, a nested
/// field group to a nested object per row.
class FieldNode {
  final String name;
  final List<FieldNode>? children;

  const FieldNode(this.name, [this.children]);
}

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

class ArrayHeaderInfo {
  final String? key;
  final int length;
  final String delimiter;
  final List<FieldNode>? fields;

  const ArrayHeaderInfo({
    this.key,
    required this.length,
    required this.delimiter,
    this.fields,
  });
}

class ArrayHeaderParseResult {
  final ArrayHeaderInfo header;
  final String? inlineValues;

  const ArrayHeaderParseResult({required this.header, this.inlineValues});
}

class KeyTokenResult {
  final String key;
  final int end;

  const KeyTokenResult({required this.key, required this.end});
}

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

class KeyValuePairResult {
  final String key;
  final JsonValue value;

  const KeyValuePairResult({required this.key, required this.value});
}
