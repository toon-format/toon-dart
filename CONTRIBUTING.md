# Contributing to toon-dart

## Development Setup

```bash
git clone --recurse-submodules https://github.com/toon-format/toon-dart.git
cd toon-dart
dart pub get
dart test
```

Run `dart format .` and `dart analyze` before committing. `dart test` runs the spec conformance fixtures from the `test/spec` submodule – see [`test/README.md`](./test/README.md) for bumping the spec tag and for `test/known_failures.dart`.

## Pull Requests

Spec behavior is tested through the spec fixtures – a missing case goes to [toon-format/spec](https://github.com/toon-format/spec) as a fixture. Changes to the format itself belong there too. Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages.
