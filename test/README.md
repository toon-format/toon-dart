# TOON Conformance Tests

`conformance_test.dart` runs every case of the [toon-format/spec](https://github.com/toon-format/spec) fixtures from the `spec` submodule, pinned to the spec tag this port implements.

To move to a later spec tag, check it out in the submodule and commit the bump:

```bash
git -C test/spec fetch --tags
git -C test/spec checkout v4.3.0
git add test/spec
```
