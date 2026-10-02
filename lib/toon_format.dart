/// TOON encoder and decoder, see https://github.com/toon-format/spec/blob/main/SPEC.md
library;

export 'src/options.dart';

import 'src/decode/decoders.dart';
import 'src/decode/scanners.dart';
import 'src/encode/encoders.dart';
import 'src/encode/normalize.dart';
import 'src/options.dart';

/// Encodes [value] as TOON after normalizing it to the JSON data model.
String encode(Object? value, {EncodeOptions? options}) {
  final normalized = normalizeValue(value);
  return encodeValue(normalized, options ?? const EncodeOptions());
}

/// Decodes TOON [input] to a `Map`, `List`, or primitive.
Object? decode(String input, {DecodeOptions? options}) {
  options ??= const DecodeOptions();
  final scanResult = toParsedLines(input, options.indent, options.strict);
  final cursor = LineCursor(scanResult.lines, scanResult.blankLines);
  return decodeValueFromLines(cursor, options);
}
