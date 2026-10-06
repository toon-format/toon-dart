class EncodeOptions {
  /// Spaces per indentation level.
  final int indent;

  /// Delimiter for inline arrays and tabular rows: `','`, `'\t'`, or `'|'`.
  final String delimiter;

  const EncodeOptions({this.indent = 2, this.delimiter = ','})
    : assert(indent > 0, 'indent must be positive');
}

class DecodeOptions {
  /// Expected spaces per indentation level.
  final int indent;

  /// Whether to throw on length mismatches, blank lines inside arrays, and
  /// tabs or uneven indentation.
  final bool strict;

  const DecodeOptions({this.indent = 2, this.strict = true})
    : assert(indent > 0, 'indent must be positive');
}
