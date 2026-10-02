import '../types.dart';
import '../utilities/constants.dart';

/// Scan result containing parsed lines and blank line information.
class ScanResult {
  final List<ParsedLine> lines;
  final List<BlankLineInfo> blankLines;

  const ScanResult({
    required this.lines,
    required this.blankLines,
  });
}

/// Line cursor for traversing parsed lines.
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

  ParsedLine? peekAtDepth(Depth targetDepth) {
    final line = peek();
    if (line == null || line.depth < targetDepth) {
      return null;
    }
    if (line.depth == targetDepth) {
      return line;
    }
    return null;
  }

  bool hasMoreAtDepth(Depth targetDepth) {
    return peekAtDepth(targetDepth) != null;
  }
}

/// Converts source string to parsed lines.
ScanResult toParsedLines(String source, int indentSize, bool strict) {
  if (source.trim().isEmpty) {
    return const ScanResult(lines: [], blankLines: []);
  }

  final lines = source.split('\n');
  final parsed = <ParsedLine>[];
  final blankLines = <BlankLineInfo>[];

  for (int i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final lineNumber = i + 1;
    int indent = 0;
    while (indent < raw.length && raw[indent] == space) {
      indent++;
    }

    final content = raw.substring(indent);

    // Track blank lines
    if (content.trim().isEmpty) {
      final depth = computeDepthFromIndent(indent, indentSize);
      blankLines.add(BlankLineInfo(lineNumber: lineNumber, indent: indent, depth: depth));
      continue;
    }

    final depth = computeDepthFromIndent(indent, indentSize);

    // Strict mode validation
    if (strict) {
      // Find the full leading whitespace region (spaces and tabs)
      int wsEnd = 0;
      while (wsEnd < raw.length && (raw[wsEnd] == space || raw[wsEnd] == tab)) {
        wsEnd++;
      }

      // Check for tabs in leading whitespace (before actual content)
      if (raw.substring(0, wsEnd).contains(tab)) {
        throw FormatException('Line $lineNumber: Tabs are not allowed in indentation in strict mode');
      }

      // Check for exact multiples of indentSize
      if (indent > 0 && indent % indentSize != 0) {
        throw FormatException('Line $lineNumber: Indentation must be exact multiple of $indentSize, but found $indent spaces');
      }
    }

    parsed.add(ParsedLine(
      raw: raw,
      indent: indent,
      content: content,
      depth: depth,
      lineNumber: lineNumber,
    ));
  }

  return ScanResult(lines: parsed, blankLines: blankLines);
}

/// Computes depth from indent spaces.
Depth computeDepthFromIndent(int indentSpaces, int indentSize) {
  return indentSpaces ~/ indentSize;
}
