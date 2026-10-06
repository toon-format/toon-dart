/// Options for `encode`.
class EncodeOptions {
  /// Spaces per indentation level.
  final int indentSize;

  /// Delimiter for inline arrays and tabular rows: `','`, `'\t'`, or `'|'`.
  final String delimiter;

  const EncodeOptions({this.indentSize = 2, this.delimiter = ','})
    : assert(indentSize > 0, 'indentSize must be positive');
}

/// Options for `decode`.
class DecodeOptions {
  /// Expected spaces per indentation level.
  final int indentSize;

  /// Whether to throw on length mismatches, blank lines inside arrays, and
  /// tabs or uneven indentation.
  final bool strict;

  const DecodeOptions({this.indentSize = 2, this.strict = true})
    : assert(indentSize > 0, 'indentSize must be positive');
}
