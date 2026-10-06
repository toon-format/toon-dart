import 'package:test/test.dart';
import 'package:toon_format/toon_format.dart';

void main() {
  test('maps Dart host types to the JSON data model', () {
    final value = {
      'big': BigInt.parse('12345678901234567890'),
      'small': BigInt.from(42),
      'date': DateTime.utc(2025, 1, 2, 3, 4, 5),
      'set': {1, 2},
      'negZero': -0.0,
      'nan': double.nan,
      'inf': double.infinity,
      'other': Object(),
    };
    expect(
      encode(value),
      'big: "12345678901234567890"\n'
      'small: 42\n'
      'date: "2025-01-02T03:04:05.000Z"\n'
      'set[2]: 1,2\n'
      'negZero: 0\n'
      'nan: null\n'
      'inf: null\n'
      'other: null',
    );
  });

  test('rejects strings and keys with an unpaired surrogate', () {
    expect(() => encode('a\uD800b'), throwsArgumentError);
    expect(() => encode({'\uDC00': 1}), throwsArgumentError);
    expect(encode('\u{1F600}'), '\u{1F600}');
  });
}
