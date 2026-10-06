# Contributing to toon-dart

## Development Setup

```bash
git clone --recurse-submodules https://github.com/toon-format/toon-dart.git
cd toon-dart
dart pub get
dart test
```

Run `dart format .` and `dart analyze --fatal-infos` before committing, as CI does. `dart test` runs the spec conformance fixtures from the `test/spec` submodule. To move to a later spec tag, check it out in the submodule and commit the bump:

```bash
git -C test/spec fetch --tags
git -C test/spec checkout vX.Y.Z
git add test/spec
```

## Pull Requests

Spec behavior is tested through the spec fixtures – a missing case goes to [toon-format/spec](https://github.com/toon-format/spec) as a fixture. Changes to the format itself belong there too. Dart-specific behavior, such as host value normalization, gets a test under `test/`. Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages.
