# Contributing to toon-dart

## Development Setup

The package requires Dart 3.0 or later (`sdk: ^3.0.0` in `pubspec.yaml`).

```bash
git clone --recurse-submodules https://github.com/toon-format/toon-dart.git
cd toon-dart
dart pub get
dart test
```

## Coding Standards

- Run `dart format .` before committing.
- Run `dart analyze` – `analysis_options.yaml` extends `package:lints/recommended.yaml` with `prefer_single_quotes`, `prefer_const_constructors`, `prefer_final_locals`, and `unnecessary_this`.
- `dart test` runs the spec conformance fixtures from the `test/spec` submodule – see [`test/README.md`](./test/README.md) for bumping the spec tag and for `test/known_failures.dart`.

## Pull Requests

Add tests for every behavior change and use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages. Changes to the format itself belong in [toon-format/spec](https://github.com/toon-format/spec).

## Maintainers

- [@g-tushar](https://github.com/g-tushar)
- [@johannschopplich](https://github.com/johannschopplich)

## License

By contributing, you agree that your contributions are licensed under the MIT License.
