import '../options.dart';
import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string_utils.dart';

void assertExpectedCount(
  int actual,
  int expected,
  String itemType,
  ParsedLine line,
  DecodeOptions options,
) {
  if (options.strict && actual != expected) {
    throw FormatException(
      expected < 0
          ? 'Line ${line.lineNumber}: Array length out of range'
          : 'Line ${line.lineNumber}: Expected $expected $itemType, but got $actual',
    );
  }
}

void validateNoBlankLinesInRange(
  int startLine,
  int endLine,
  List<int> blankLines,
  String context,
) {
  // Any blank line between the first and last item fails, whatever its
  // indentation.
  final blank = blankLines
      .where((line) => line > startLine && line < endLine)
      .firstOrNull;
  if (blank != null) {
    throw FormatException(
      'Line $blank: Blank lines inside $context are not allowed in strict mode',
    );
  }
}

/// Tells a tabular row from a key-value line: a row has no colon, or a
/// delimiter before its first colon.
bool isDataRow(String content, String delimiter) {
  final colonPos = findUnquotedChar(content, colon);
  final delimiterPos = findUnquotedChar(content, delimiter);
  return colonPos == -1 || (delimiterPos != -1 && delimiterPos < colonPos);
}
