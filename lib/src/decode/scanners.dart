import '../types.dart';
import '../utilities/constants.dart';

class ScanResult {
  final List<ParsedLine> lines;
  final List<BlankLineInfo> blankLines;

  const ScanResult({required this.lines, required this.blankLines});
}

class LineCursor {
  final List<ParsedLine> _lines;
  int _index;
  final List<BlankLineInfo> _blankLines;

  LineCursor(this._lines, [List<BlankLineInfo>? blankLines])
    : _index = 0,
      _blankLines = blankLines ?? [];

  List<BlankLineInfo> getBlankLines() {
    return _blankLines;
  }

  ParsedLine? peek() {
    if (_index >= _lines.length) return null;
    return _lines[_index];
  }

  ParsedLine? next() {
    if (_index >= _lines.length) return null;
    return _lines[_index++];
  }

  ParsedLine? current() {
    return _index > 0 ? _lines[_index - 1] : null;
  }

  void advance() {
    _index++;
  }

  bool atEnd() {
    return _index >= _lines.length;
  }

  int get length => _lines.length;
}

ScanResult toParsedLines(String source, int indentSize, bool strict) {
  final lines = source.split('\n');
  final parsed = <ParsedLine>[];
  final blankLines = <BlankLineInfo>[];

  for (int i = 0; i < lines.length; i++) {
    var raw = lines[i];
    final lineNumber = i + 1;
    if (i == 0 && raw.startsWith(byteOrderMark)) {
      raw = raw.substring(1);
    }
    // A trailing carriage return belongs to the CRLF terminator.
    if (raw.endsWith(carriageReturn)) {
      raw = raw.substring(0, raw.length - 1);
    }
    var whitespaceEnd = 0;
    while (whitespaceEnd < raw.length &&
        (raw[whitespaceEnd] == space || raw[whitespaceEnd] == tab)) {
      whitespaceEnd++;
    }
    final leadingWhitespace = raw.substring(0, whitespaceEnd);
    final firstTabIndex = leadingWhitespace.indexOf(tab);

    // Strict rejects tab indentation below, so only the spaces before the
    // first tab are indentation there.
    final indent = strict && firstTabIndex != -1
        ? firstTabIndex
        : whitespaceEnd;
    // Non-strict input may indent with tabs, each counting as one depth level.
    final tabIndent = strict || firstTabIndex == -1
        ? 0
        : tab.allMatches(leadingWhitespace).length;
    final content = _trimTrailingSpaces(raw.substring(indent));

    // Only spaces may precede the comment marker. Comment lines vanish before
    // blank-line tracking and strict validation.
    if (firstTabIndex == -1 && content.startsWith(commentMarker)) {
      continue;
    }

    final depth = (indent - tabIndent) ~/ indentSize + tabIndent;

    if (content.isEmpty) {
      blankLines.add(
        BlankLineInfo(lineNumber: lineNumber, indent: indent, depth: depth),
      );
      continue;
    }

    if (strict) {
      if (firstTabIndex != -1) {
        throw FormatException(
          'Line $lineNumber: Tabs are not allowed in indentation in strict mode',
        );
      }

      if (indent > 0 && indent % indentSize != 0) {
        throw FormatException(
          'Line $lineNumber: Indentation must be exact multiple of $indentSize, but found $indent spaces',
        );
      }
    }

    parsed.add(
      ParsedLine(
        raw: raw,
        indent: indent,
        content: content,
        depth: depth,
        lineNumber: lineNumber,
      ),
    );
  }

  return ScanResult(lines: parsed, blankLines: blankLines);
}

String _trimTrailingSpaces(String value) {
  var end = value.length;
  while (end > 0 && value.codeUnitAt(end - 1) == 0x20) {
    end--;
  }
  return value.substring(0, end);
}
