import '../types.dart';

JsonValue normalizeValue(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is String) {
    return _assertNoLoneSurrogate(value);
  }

  if (value is bool) {
    return value;
  }

  if (value is num) {
    if (value == 0 && value.isNegative) {
      return 0;
    }
    if (!value.isFinite) {
      return null;
    }
    return value;
  }

  if (value is BigInt) {
    // Beyond ±(2^53 − 1) a double loses integer precision, so encode a string.
    final minSafe = BigInt.from(-9007199254740991);
    final maxSafe = BigInt.from(9007199254740991);
    if (value >= minSafe && value <= maxSafe) {
      return value.toInt();
    }
    return value.toString();
  }

  if (value is DateTime) {
    return value.toIso8601String();
  }

  if (value is List) {
    return value.map((item) => normalizeValue(item)).toList();
  }

  if (value is Set) {
    return value.map((item) => normalizeValue(item)).toList();
  }

  if (value is Map) {
    final result = <String, JsonValue>{};
    for (final entry in value.entries) {
      result[_assertNoLoneSurrogate(entry.key.toString())] = normalizeValue(
        entry.value,
      );
    }
    return result;
  }

  return null;
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
