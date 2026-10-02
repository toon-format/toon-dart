/// Options for encoding to TOON format.
class EncodeOptions {
  /// Number of spaces per indentation level (default: 2).
  final int indent;

  /// Delimiter for array values and tabular rows (default: ',').
  final String delimiter;

  const EncodeOptions({
    this.indent = 2,
    this.delimiter = ',',
  }) : assert(indent > 0, 'indent must be positive');
}

/// Options for decoding from TOON format.
class DecodeOptions {
  /// Expected number of spaces per indentation level (default: 2).
  final int indent;

  /// Enable strict validation (default: true).
  final bool strict;

  const DecodeOptions({
    this.indent = 2,
    this.strict = true,
  }) : assert(indent > 0, 'indent must be positive');
}
