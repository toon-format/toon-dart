/// Encodes and decodes TOON (Token-Oriented Object Notation) per
/// [TOON spec v4.3](https://github.com/toon-format/spec/blob/v4.3.0/SPEC.md).
library;

export 'src/options.dart';

import 'src/decode/decoders.dart';
import 'src/decode/scanners.dart';
import 'src/encode/encoders.dart';
import 'src/encode/normalize.dart';
import 'src/options.dart';

/// Encodes [value] as TOON after normalizing it to the JSON data model.
///
/// Throws an [ArgumentError] on a string or key with an unpaired surrogate,
/// or on an `indentSize` below 1.
String encode(Object? value, {EncodeOptions? options}) {
  options ??= const EncodeOptions();
  _checkIndentSize(options.indentSize);
  return encodeValue(normalizeValue(value), options);
}

/// Decodes TOON [input] to a `Map`, `List`, or primitive; numbers decode as
/// `double`.
///
/// Throws a [FormatException] on malformed input, and an [ArgumentError] on an
/// `indentSize` below 1.
Object? decode(String input, {DecodeOptions? options}) {
  options ??= const DecodeOptions();
  _checkIndentSize(options.indentSize);
  final cursor = scanLines(input, options.indentSize, options.strict);
  return decodeValueFromLines(cursor, options);
}

void _checkIndentSize(int indentSize) {
  if (indentSize < 1) {
    throw ArgumentError.value(indentSize, 'indentSize', 'must be at least 1');
  }
}
