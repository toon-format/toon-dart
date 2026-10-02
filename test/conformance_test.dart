import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:toon_format/toon_format.dart';

import 'known_failures.dart';

void main() {
  for (final category in const ['encode', 'decode']) {
    final files = Directory('test/fixtures/$category')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final run = category == 'encode' ? _runEncode : _runDecode;

    group(category, () {
      for (final file in files) {
        final fileName = file.uri.pathSegments.last;
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final cases = (fixture['tests'] as List).cast<Map<String, dynamic>>();

        group(fileName, () {
          for (var i = 0; i < cases.length; i++) {
            final fixtureCase = cases[i];
            final id = '$category/$fileName#$i';
            test('#$i ${fixtureCase['name']}', () {
              if (!knownFailures.contains(id)) return run(fixtureCase);
              try {
                run(fixtureCase);
              } catch (_) {
                return;
              }
              fail('$id passes now – remove it from known_failures.dart');
            });
          }
        });
      }
    });
  }
}

void _runEncode(Map<String, dynamic> fixtureCase) {
  final options =
      _encodeOptions(fixtureCase['options'] as Map<String, dynamic>?);
  if (fixtureCase['shouldError'] == true) {
    expect(() => encode(fixtureCase['input'], options: options),
        throwsA(anything));
    return;
  }
  expect(encode(fixtureCase['input'], options: options),
      equals(fixtureCase['expected']));
}

void _runDecode(Map<String, dynamic> fixtureCase) {
  final options =
      _decodeOptions(fixtureCase['options'] as Map<String, dynamic>?);
  final input = fixtureCase['input'] as String;
  if (fixtureCase['shouldError'] == true) {
    expect(() => decode(input, options: options), throwsA(anything));
    return;
  }
  final actual = decode(input, options: options);
  expect(
    _jsonModelEquals(actual, fixtureCase['expected']),
    isTrue,
    reason: 'expected ${jsonEncode(fixtureCase['expected'])}\n'
        '     got ${_safeJson(actual)}',
  );
}

EncodeOptions? _encodeOptions(Map<String, dynamic>? fixtureOptions) {
  if (fixtureOptions == null) return null;
  return EncodeOptions(
    indent: (fixtureOptions['indentSize'] ?? 2) as int,
    delimiter: (fixtureOptions['delimiter'] ?? ',') as String,
  );
}

DecodeOptions? _decodeOptions(Map<String, dynamic>? fixtureOptions) {
  if (fixtureOptions == null) return null;
  return DecodeOptions(
    indent: (fixtureOptions['indentSize'] ?? 2) as int,
    strict: (fixtureOptions['strict'] ?? true) as bool,
  );
}

/// JSON-model equality per spec §2: ordered keys, exact strings,
/// mathematical number equality.
bool _jsonModelEquals(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  if (a is String || b is String) return a == b;
  if (a is bool || b is bool || a == null || b == null) return a == b;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonModelEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    final actualKeys = a.keys.toList();
    final expectedKeys = b.keys.toList();
    for (var i = 0; i < actualKeys.length; i++) {
      if (actualKeys[i] != expectedKeys[i]) return false;
      if (!_jsonModelEquals(a[actualKeys[i]], b[expectedKeys[i]])) return false;
    }
    return true;
  }
  return false;
}

String _safeJson(Object? value) {
  try {
    return jsonEncode(value);
  } catch (_) {
    return '$value';
  }
}
