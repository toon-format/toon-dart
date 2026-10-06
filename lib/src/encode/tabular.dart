import '../types.dart';
import 'normalize.dart';

/// Returns the field list of uniformly tabular [rows], or null.
List<FieldNode>? extractTabularFields(List<JsonObject> rows) {
  if (rows.isEmpty) return null;

  final firstKeys = rows[0].keys.toList();
  if (firstKeys.isEmpty) return null;

  // Rows may list the same keys in a different order.
  for (final row in rows) {
    if (row.length != firstKeys.length || !firstKeys.every(row.containsKey)) {
      return null;
    }
  }

  final fields = <FieldNode>[];
  for (final key in firstKeys) {
    final field = _classifyColumn(key, [for (final row in rows) row[key]]);
    if (field == null) return null;
    fields.add(field);
  }
  return fields;
}

/// Reads one row's leaf cells in the order of [fields].
List<JsonPrimitive> collectRowLeaves(JsonObject row, List<FieldNode> fields) {
  return [
    for (final field in fields)
      if (field.children case final children?)
        ...collectRowLeaves(row[field.name] as JsonObject, children)
      else
        row[field.name],
  ];
}

FieldNode? _classifyColumn(String name, List<JsonValue> values) {
  if (values.every(isJsonPrimitive)) return FieldNode(name);

  // Non-empty objects sharing one key set become a nested field group.
  if (!values.every((value) => value is JsonObject && value.isNotEmpty)) {
    return null;
  }
  final children = extractTabularFields(values.cast<JsonObject>());
  return children == null ? null : FieldNode(name, children);
}
