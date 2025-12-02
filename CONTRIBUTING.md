# Contributing to toon-dart

Thank you for your interest in contributing to the official Dart implementation of TOON!

## Project Setup

This project uses Dart and pub for dependency management.

```bash
# Clone the repository
git clone https://github.com/toon-format/toon-dart.git
cd toon-dart

# Get dependencies
dart pub get

# Run tests
dart test

# Run tests with coverage
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

## Development Workflow

1. **Fork the repository** and create a feature branch
2. **Make your changes** following the coding standards below
3. **Add tests** for any new functionality
4. **Ensure all tests pass** and coverage remains high
5. **Submit a pull request** with a clear description

## Coding Standards

### Dart Version Support

This project targets Dart 3.0 and above.

### Code Style

- Follow standard Dart formatting conventions
- Run `dart format` before committing
- Run `dart analyze` to catch common mistakes

### Testing

- All new features must include tests
- Maintain test coverage at **85%+ line coverage**
- Tests should cover edge cases and spec compliance
- Run the full test suite:
  ```bash
  dart test
  ```

## SPEC Compliance

All implementations must comply with the [TOON specification](https://github.com/toon-format/spec/blob/main/SPEC.md).

Before submitting changes that affect encoding/decoding behavior:
1. Verify against the official SPEC.md
2. Add tests for the specific spec sections you're implementing
3. Document any spec version requirements

## Pull Request Guidelines

- **Title**: Use a clear, descriptive title
- **Description**: Explain what changes you made and why
- **Tests**: Include tests for your changes
- **Documentation**: Update README or documentation if needed
- **Commits**: Use clear commit messages ([Conventional Commits](https://www.conventionalcommits.org/) preferred)

Your pull request will use our standard template which guides you through the required information.

## Communication

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Pull Requests**: For code reviews and implementation discussion
- **[Discord](https://discord.gg/ywXDMFdx)**: For real-time chat with the community

## Maintainers

This is a collaborative project. Current maintainers:

- [@g-tushar](https://github.com/g-tushar)
- [@johannschopplich](https://github.com/johannschopplich)

All maintainers have equal and consensual decision-making power. For major architectural decisions, please open a discussion issue first.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
