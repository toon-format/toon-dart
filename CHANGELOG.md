## Unreleased

- Target [TOON spec v4.3](https://github.com/toon-format/spec/blob/v4.3.0/SPEC.md): keyed tabular objects, nested field groups, comment lines, `\uXXXX` escapes, the `[]` empty-array literal, and the stricter quoting and header rules; every conformance fixture passes
- **Breaking:** `EncodeOptions.indent` and `DecodeOptions.indent` are now `indentSize`
- **Breaking:** `EncodeOptions.delimiter` is a `Delimiter` enum (`comma`, `tab`, `pipe`) instead of a `String`
- **Breaking:** `decode` throws a `FormatException` instead of a `RangeError` when a count or row width does not match its header
- **Breaking:** `decode` with `strict: false` no longer skips over-indented lines or content after a root array or keyed table, reads a malformed or misplaced header as a key-value line, or tolerates a row width mismatch
- `encode` writes an `int` beyond ±(2^53 − 1) as a quoted decimal string, like a `BigInt`
- `encode` writes any `Iterable` as an array, not only a `List` or `Set`
- `encode` throws an `ArgumentError` on a string or key with an unpaired surrogate
- `encode` and `decode` throw an `ArgumentError` on an `indentSize` below 1, also in release builds
- `decode` returns zero as a `double`, like every other number
- Every `decode` error message starts with its line number

## 0.1.0

- Initial release
- Reserved package namespace on pub.dev
- Implementation pending
