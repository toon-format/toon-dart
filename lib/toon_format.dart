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
/// Throws an [ArgumentError] on a string or key with an unpaired surrogate.
String encode(Object? value, {EncodeOptions? options}) {
  final normalized = normalizeValue(value);
  return encodeValue(normalized, options ?? const EncodeOptions());
}

/// Decodes TOON [input] to a `Map`, `List`, or primitive; numbers decode as
/// `double`.
///
/// Throws a [FormatException] on malformed input.
Object? decode(String input, {DecodeOptions? options}) {
  options ??= const DecodeOptions();
  final cursor = scanLines(input, options.indentSize, options.strict);
  return decodeValueFromLines(cursor, options);
}
