import '../types.dart';

// #region Normalization (unknown → JsonValue)

JsonValue normalizeValue(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is String || value is bool) {
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
      result[entry.key.toString()] = normalizeValue(entry.value);
    }
    return result;
  }

  return null;
}

// #endregion

// #region Type guards

bool isJsonPrimitive(Object? value) {
  return value == null ||
      value is String ||
      value is num ||
      value is bool;
}

bool isJsonArray(Object? value) {
  return value is List;
}

bool isJsonObject(Object? value) {
  return value != null && value is Map<String, Object?>;
}

// #endregion

// #region Array type detection

bool isArrayOfPrimitives(JsonArray value) {
  return value.every((item) => isJsonPrimitive(item));
}

bool isArrayOfArrays(JsonArray value) {
  return value.every((item) => isJsonArray(item));
}

bool isArrayOfObjects(JsonArray value) {
  return value.every((item) => isJsonObject(item));
}

// #endregion
