import '../types.dart';

// 2^53 − 1: beyond it a double loses integer precision, so a larger BigInt
// encodes as a string.
final _maxSafeInteger = BigInt.from(9007199254740991);

JsonValue normalizeValue(Object? value) {
  return switch (value) {
    null || bool() => value,
    String() => _assertNoLoneSurrogate(value),
    num() when !value.isFinite => null,
    num() when value == 0 && value.isNegative => 0,
    num() => value,
    BigInt() when value.abs() <= _maxSafeInteger => value.toInt(),
    BigInt() => value.toString(),
    DateTime() => value.toIso8601String(),
    List() => value.map(normalizeValue).toList(),
    Set() => value.map(normalizeValue).toList(),
    Map() => <String, JsonValue>{
      for (final entry in value.entries)
        _assertNoLoneSurrogate('${entry.key}'): normalizeValue(entry.value),
    },
    _ => null,
  };
}

// A lone surrogate has no UTF-8 form, so emitting it would silently substitute
// U+FFFD and break round-tripping.
String _assertNoLoneSurrogate(String value) {
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit < 0xD800 || unit > 0xDFFF) continue;
    if (unit <= 0xDBFF &&
        i + 1 < value.length &&
        (value.codeUnitAt(i + 1) & 0xFC00) == 0xDC00) {
      i++;
      continue;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unpaired surrogate U+${unit.toRadixString(16).toUpperCase()} at index $i',
    );
  }
  return value;
}

bool isJsonPrimitive(Object? value) {
  return value == null || value is String || value is num || value is bool;
}

bool isArrayOfPrimitives(JsonArray value) => value.every(isJsonPrimitive);

bool isArrayOfObjects(JsonArray value) =>
    value.every((item) => item is JsonObject);
