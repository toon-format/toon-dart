# TOON Format for Dart

[![pub package](https://img.shields.io/pub/v/toon_format.svg)](https://pub.dev/packages/toon_format)
[![Documentation](https://pub.dev/documentation/toon_format/latest/)](https://pub.dev/documentation/toon_format/latest/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

**Token-Oriented Object Notation** is a compact, human-readable format designed for passing structured data to Large Language Models with significantly reduced token usage.

## Status

🚧 **This package is currently a namespace reservation.** Full implementation coming soon!

### Example

**JSON** (verbose):
```json
{
  "users": [
    { "id": 1, "name": "Alice", "role": "admin" },
    { "id": 2, "name": "Bob", "role": "user" }
  ]
}
```

**TOON** (compact):
```
users[2]{id,name,role}:
  1,Alice,admin
  2,Bob,user
```

## Resources

- [TOON Specification](https://github.com/johannschopplich/toon/blob/main/SPEC.md)
- [Main Repository](https://github.com/johannschopplich/toon)
- [Benchmarks & Performance](https://github.com/johannschopplich/toon#benchmarks)
- [Other Language Implementations](https://github.com/johannschopplich/toon#other-implementations)

## Future Usage

Once implemented, the package will provide:

```dart
import 'package:toon_format/toon_format.dart';

void main() {
  final data = {
    'users': [
      {'id': 1, 'name': 'Alice', 'role': 'admin'},
      {'id': 2, 'name': 'Bob', 'role': 'user'}
    ]
  };

  final toonString = encode(data);
  final decoded = decode(toonString);
}
```

## Contributing

Interested in implementing TOON for Dart? Check out the [specification](https://github.com/johannschopplich/toon/blob/main/SPEC.md) and feel free to contribute!

## Contributors
- **[Tushar Gupta](https://github.com/Tushargupta9800)**

## License

MIT License © 2025-PRESENT [Johann Schopplich](https://github.com/johannschopplich)
MIT License © 2025-PRESENT [Tushar Gupta](https://github.com/Tushargupta9800)