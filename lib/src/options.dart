/// Delimiter for inline arrays and tabular rows.
enum Delimiter {
  comma(','),
  tab('\t'),
  pipe('|');

  const Delimiter(this.symbol);

  final String symbol;
}

/// Options for `encode`.
class EncodeOptions {
  /// Spaces per indentation level.
  final int indentSize;

  /// Delimiter for inline arrays and tabular rows.
  final Delimiter delimiter;

  const EncodeOptions({this.indentSize = 2, this.delimiter = Delimiter.comma});
}

/// Options for `decode`.
class DecodeOptions {
  /// Expected spaces per indentation level.
  final int indentSize;

  /// Whether to enforce the spec's strict-mode errors, such as count
  /// mismatches, duplicate keys, or tab indentation.
  final bool strict;

  const DecodeOptions({this.indentSize = 2, this.strict = true});
}
