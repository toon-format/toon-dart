# TOON for Dart

[![SPEC v1.4](https://img.shields.io/badge/spec-v1.4-lightgrey)](https://github.com/toon-format/spec/blob/v1.4.0/SPEC.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

Encodes Dart values to [TOON (Token-Oriented Object Notation)](https://github.com/toon-format/toon) and decodes TOON back. TOON is a compact, indentation-based encoding of the JSON data model for LLM input.

## Installation

The `0.1.0` release on pub.dev is a namespace placeholder, so install from Git:

```bash
dart pub add toon_format --git-url https://github.com/toon-format/toon-dart.git
```

## Usage

```dart
import 'package:toon_format/toon_format.dart';

void main() {
  final toon = encode({
    'users': [
      {'id': 1, 'name': 'Ada', 'role': 'admin'},
      {'id': 2, 'name': 'Bob', 'role': 'user'},
    ],
  });
  print(toon);
  // users[2]{id,name,role}:
  //   1,Ada,admin
  //   2,Bob,user

  print(decode(toon));
  // {users: [{id: 1.0, name: Ada, role: admin}, {id: 2.0, name: Bob, role: user}]}
}
```

Pass `EncodeOptions` to `encode` and `DecodeOptions` to `decode`, e.g. `encode(data, options: const EncodeOptions(delimiter: '|'))`:

| Option | Default | Description |
| ------ | ------- | ----------- |
| `EncodeOptions.indent` | `2` | Spaces per indentation level |
| `EncodeOptions.delimiter` | `','` | Delimiter for inline arrays and tabular rows: `','`, `'\t'`, or `'\|'` |
| `DecodeOptions.indent` | `2` | Expected spaces per indentation level |
| `DecodeOptions.strict` | `true` | Error on length mismatches, blank lines inside arrays, and tabs or uneven indentation |

## Specification

Targets [TOON spec v1.4](https://github.com/toon-format/spec/blob/v1.4.0/SPEC.md). The test suite runs the spec's conformance fixtures, and [`test/known_failures.dart`](./test/known_failures.dart) lists the cases this port does not pass yet.

- **Numbers decode to `double`** – a token that overflows `double` (e.g. `1e999`) stays a string, and integers beyond 2^53 lose precision ([§4](https://github.com/toon-format/spec/blob/v1.4.0/SPEC.md#4-decoding-interpretation-reference-decoder))
- **Host values normalize to the JSON model** – `NaN` and infinities → `null`, `-0.0` → `0`, `BigInt` → number within ±(2^53 − 1) and a quoted decimal string beyond, `DateTime` → ISO 8601 string, `Set` → array, `Map` keys → `toString()`, anything else → `null` ([§3](https://github.com/toon-format/spec/blob/v1.4.0/SPEC.md#3-encoding-normalization-reference-encoder))

## Resources

- **Specification:** [SPEC.md](https://github.com/toon-format/spec/blob/main/SPEC.md) – Normative rules and conformance checklists
- **Format Overview:** [toonformat.dev](https://toonformat.dev/guide/format-overview) – Every form with examples
- **Other Implementations:** [toonformat.dev](https://toonformat.dev/ecosystem/implementations) – TOON in other languages
- **Example:** [example/example.dart](./example/example.dart) – The usage snippet as a runnable file

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the development setup and pull request guidelines.

## License

[MIT](./LICENSE) License © 2025-PRESENT [Tushar Gupta](https://github.com/Tushargupta9800) and [Johann Schopplich](https://github.com/johannschopplich)
