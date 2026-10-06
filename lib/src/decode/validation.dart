import '../options.dart';
import '../types.dart';
import '../utilities/constants.dart';
import '../utilities/string_utils.dart';
import 'scanners.dart';

void assertExpectedCount(
  int actual,
  int expected,
  String itemType,
  DecodeOptions options,
) {
  if (options.strict && actual != expected) {
    throw RangeError('Expected $expected $itemType, but got $actual');
  }
}

void validateNoExtraListItems(
  LineCursor cursor,
  int itemDepth,
  int expectedCount,
) {
  if (cursor.atEnd) return;

  final nextLine = cursor.peek();
  if (nextLine != null &&
      nextLine.depth == itemDepth &&
      nextLine.content.startsWith(listItemPrefix)) {
    throw RangeError(
      'Expected $expectedCount list array items, but found more',
    );
  }
}

void validateNoExtraTabularRows(
  LineCursor cursor,
  int rowDepth,
  ArrayHeaderInfo header,
) {
  if (cursor.atEnd) return;

  final nextLine = cursor.peek();
  if (nextLine != null &&
      nextLine.depth == rowDepth &&
      !nextLine.content.startsWith(listItemPrefix) &&
      isDataRow(nextLine.content, header.delimiter)) {
    throw RangeError('Expected ${header.length} tabular rows, but found more');
  }
}

void validateNoBlankLinesInRange(
  int startLine,
  int endLine,
  List<int> blankLines,
  bool strict,
  String context,
) {
  if (!strict) return;

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

  if (colonPos == -1) {
    return true;
  }

  if (delimiterPos != -1 && delimiterPos < colonPos) {
    return true;
  }

  return false;
}
