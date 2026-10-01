/// Token-Oriented Object Notation (TOON) encoder and decoder for Dart.
///
/// TOON is a compact, human-readable format designed for passing structured
/// data to Large Language Models with significantly reduced token usage.
///
/// This package is currently under development.
/// For specification, see: https://github.com/johannschopplich/toon/blob/main/SPEC.md
library toon_format;

export 'src/options.dart';

import 'src/decode/decoders.dart';
import 'src/decode/scanners.dart';
import 'src/encode/encoders.dart';
import 'src/encode/normalize.dart';
import 'src/options.dart';

/// Encodes a value to TOON format.
///
/// [value] The value to encode (will be normalized to JSON-compatible types)
/// [options] Optional encoding options
/// Returns a TOON-formatted string
String encode(Object? value, {EncodeOptions? options}) {
  final normalized = normalizeValue(value);
  final resolvedOptions = (options ?? const EncodeOptions()).resolve();
  return encodeValue(normalized, resolvedOptions);
}

/// Decodes a TOON-formatted string to a Dart value.
///
/// [input] The TOON-formatted string to parse
/// [options] Optional decoding options
/// Returns a Dart value (Map, List, or primitive) representing the parsed TOON data
Object? decode(String input, {DecodeOptions? options}) {
  final resolvedOptions = (options ?? const DecodeOptions()).resolve();
  final scanResult = toParsedLines(input, resolvedOptions.indent, resolvedOptions.strict);
  final cursor = LineCursor(scanResult.lines, scanResult.blankLines);
  return decodeValueFromLines(cursor, resolvedOptions);
}
