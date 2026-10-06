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
  final String content;
  final int depth;
  final int lineNumber;

  const ParsedLine({
    required this.content,
    required this.depth,
    required this.lineNumber,
  });
}

class ArrayHeaderInfo {
  final String? key;
  final int length;
  final String delimiter;
  final List<FieldNode>? fields;

  /// Whether this is a keyed tabular header `[N:]`, which decodes to an object
  /// of N entries.
  final bool keyed;

  const ArrayHeaderInfo({
    this.key,
    required this.length,
    required this.delimiter,
    this.fields,
    this.keyed = false,
  });
}

class ArrayHeaderParseResult {
  final ArrayHeaderInfo header;
  final String? inlineValues;

  const ArrayHeaderParseResult({required this.header, this.inlineValues});
}
