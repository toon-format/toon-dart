/// Options for `encode`.
class EncodeOptions {
  /// Spaces per indentation level.
  final int indentSize;

  /// Delimiter for inline arrays and tabular rows: `','`, `'\t'`, or `'|'`.
  final String delimiter;

  const EncodeOptions({this.indentSize = 2, this.delimiter = ','})
    : assert(indentSize > 0, 'indentSize must be positive'),
      assert(
        delimiter == ',' || delimiter == '\t' || delimiter == '|',
        "delimiter must be ',', '\\t', or '|'",
      );
}

/// Options for `decode`.
class DecodeOptions {
  /// Expected spaces per indentation level.
  final int indentSize;

  /// Whether to enforce the spec's strict-mode errors, such as count
  /// mismatches, duplicate keys, or tab indentation.
  final bool strict;

  const DecodeOptions({this.indentSize = 2, this.strict = true})
    : assert(indentSize > 0, 'indentSize must be positive');
}
