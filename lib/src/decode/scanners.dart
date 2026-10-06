import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string_utils.dart';

class LineCursor {
  final List<ParsedLine> _lines;

  /// Line numbers of the blank lines, which strict mode rejects inside arrays.
  final List<int> blankLines;

  int _index = 0;

  LineCursor(this._lines, this.blankLines);

  int get length => _lines.length;

  bool get atEnd => _index >= _lines.length;

  /// The line most recently consumed.
  ParsedLine? get current => _index > 0 ? _lines[_index - 1] : null;

  ParsedLine? peek() => atEnd ? null : _lines[_index];

  ParsedLine? next() => atEnd ? null : _lines[_index++];

  void advance() => _index++;
}

LineCursor scanLines(String source, int indentSize, bool strict) {
  final lines = source.split('\n');
  final parsed = <ParsedLine>[];
  final blankLines = <int>[];

  for (var i = 0; i < lines.length; i++) {
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
    final content = trimSpaces(raw.substring(indent));

    // Only spaces may precede the comment marker. Comment lines vanish before
    // blank-line tracking and strict validation.
    if (firstTabIndex == -1 && content.startsWith(commentMarker)) {
      continue;
    }

    if (content.isEmpty) {
      blankLines.add(lineNumber);
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

    final depth = (indent - tabIndent) ~/ indentSize + tabIndent;
    parsed.add(
      ParsedLine(content: content, depth: depth, lineNumber: lineNumber),
    );
  }

  return LineCursor(parsed, blankLines);
}
