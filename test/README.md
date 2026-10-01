# TOON Conformance Tests

`conformance_test.dart` runs every case of the [toon-format/spec](https://github.com/toon-format/spec) fixtures, vendored in `fixtures/` from the tag in `fixtures/VERSION`. Cases in `known_failures.dart` must still fail; remove an entry once its case passes.

To sync a later spec tag:

```bash
TAG=v4.1.2
rm -rf test/fixtures/encode test/fixtures/decode
curl -sL "https://github.com/toon-format/spec/archive/refs/tags/$TAG.tar.gz" \
  | tar -xz -C test/fixtures --strip-components=3 "spec-${TAG#v}/tests/fixtures"
echo "$TAG" > test/fixtures/VERSION
```
