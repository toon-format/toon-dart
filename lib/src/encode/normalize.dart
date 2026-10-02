import '../types.dart';

// #region Normalization (unknown → JsonValue)

/// Normalizes a value to a JsonValue.
JsonValue normalizeValue(Object? value) {
  // null
  if (value == null) {
    return null;
  }

  // Primitives
  if (value is String || value is bool) {
    return value;
  }

  // Numbers: canonicalize -0 to 0, handle NaN and Infinity
  if (value is num) {
    if (value == 0 && value.isNegative) {
      return 0;
    }
    if (!value.isFinite) {
      return null;
    }
    return value;
  }

  // BigInt → number (if safe) or string
  if (value is BigInt) {
    // Try to convert to number if within safe integer range
    final minSafe = BigInt.from(-9007199254740991);
    final maxSafe = BigInt.from(9007199254740991);
    if (value >= minSafe && value <= maxSafe) {
      return value.toInt();
    }
    // Otherwise convert to string (will be unquoted as it looks numeric)
    return value.toString();
  }

  // DateTime → ISO string
  if (value is DateTime) {
    return value.toIso8601String();
  }

  // Array
  if (value is List) {
    return value.map((item) => normalizeValue(item)).toList();
  }

  // Set → array
  if (value is Set) {
    return value.map((item) => normalizeValue(item)).toList();
  }

  // Map → object
  if (value is Map) {
    final result = <String, JsonValue>{};
    for (final entry in value.entries) {
      result[entry.key.toString()] = normalizeValue(entry.value);
    }
    return result;
  }

  // Plain object - already handled by Map case above
  // In Dart, plain objects would need reflection to convert, which is not available
  // So we only handle Maps, Lists, Sets, and primitives

  // Fallback: function, symbol, undefined, or other → null
  return null;
}

// #endregion

// #region Type guards

/// Checks if a value is a JSON primitive.
bool isJsonPrimitive(Object? value) {
  return value == null ||
      value is String ||
      value is num ||
      value is bool;
}

/// Checks if a value is a JSON array.
bool isJsonArray(Object? value) {
  return value is List;
}

/// Checks if a value is a JSON object.
bool isJsonObject(Object? value) {
  return value != null && value is Map<String, Object?>;
}

// #endregion

// #region Array type detection

/// Checks if an array contains only primitives.
bool isArrayOfPrimitives(JsonArray value) {
  return value.every((item) => isJsonPrimitive(item));
}

/// Checks if an array contains only arrays.
bool isArrayOfArrays(JsonArray value) {
  return value.every((item) => isJsonArray(item));
}

/// Checks if an array contains only objects.
bool isArrayOfObjects(JsonArray value) {
  return value.every((item) => isJsonObject(item));
}

// #endregion
