import '../options.dart';
import '../types.dart';
import '../utilities/constants.dart';
import 'scanners.dart';

/// Asserts that the actual count matches the expected count in strict mode.
///
/// [actual] The actual count
/// [expected] The expected count
/// [itemType] The type of items being counted (e.g., `list array items`, `tabular rows`)
/// [options] Decode options
/// Throws [RangeError] if counts don't match in strict mode
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

/// Validates that there are no extra list items beyond the expected count.
///
/// [cursor] The line cursor
/// [itemDepth] The expected depth of items
/// [expectedCount] The expected number of items
/// Throws [RangeError] if extra items are found
void validateNoExtraListItems(
  LineCursor cursor,
  Depth itemDepth,
  int expectedCount,
) {
  if (cursor.atEnd()) return;

  final nextLine = cursor.peek();
  if (nextLine != null && nextLine.depth == itemDepth && nextLine.content.startsWith(LIST_ITEM_PREFIX)) {
    throw RangeError('Expected $expectedCount list array items, but found more');
  }
}

/// Validates that there are no extra tabular rows beyond the expected count.
///
/// [cursor] The line cursor
/// [rowDepth] The expected depth of rows
/// [header] The array header info containing length and delimiter
/// Throws [RangeError] if extra rows are found
void validateNoExtraTabularRows(
  LineCursor cursor,
  Depth rowDepth,
  ArrayHeaderInfo header,
) {
  if (cursor.atEnd()) return;

  final nextLine = cursor.peek();
  if (nextLine != null &&
      nextLine.depth == rowDepth &&
      !nextLine.content.startsWith(LIST_ITEM_PREFIX) &&
      isDataRow(nextLine.content, header.delimiter)) {
    throw RangeError('Expected ${header.length} tabular rows, but found more');
  }
}

/// Validates that there are no blank lines within a specific line range and depth.
///
/// In strict mode, blank lines inside arrays/tabular rows are not allowed.
///
/// [startLine] The starting line number (inclusive)
/// [endLine] The ending line number (inclusive)
/// [blankLines] Array of blank line information
/// [strict] Whether strict mode is enabled
/// [context] Description of the context (e.g., "list array", "tabular array")
/// Throws [FormatException] if blank lines are found in strict mode
void validateNoBlankLinesInRange(
  int startLine,
  int endLine,
  List<BlankLineInfo> blankLines,
  bool strict,
  String context,
) {
  if (!strict) return;

  // Find blank lines within the range
  // Note: We don't filter by depth because ANY blank line between array items is an error,
  // regardless of its indentation level
  final blanksInRange = blankLines.where(
    (blank) => blank.lineNumber > startLine && blank.lineNumber < endLine,
  ).toList();

  if (blanksInRange.isNotEmpty) {
    throw FormatException(
      'Line ${blanksInRange[0].lineNumber}: Blank lines inside $context are not allowed in strict mode',
    );
  }
}

/// Checks if a line represents a data row (as opposed to a key-value pair) in a tabular array.
///
/// [content] The line content
/// [delimiter] The delimiter used in the table
/// Returns true if the line is a data row, false if it's a key-value pair
bool isDataRow(String content, String delimiter) {
  final colonPos = content.indexOf(COLON);
  final delimiterPos = content.indexOf(delimiter);

  // No colon = definitely a data row
  if (colonPos == -1) {
    return true;
  }

  // Has delimiter and it comes before colon = data row
  if (delimiterPos != -1 && delimiterPos < colonPos) {
    return true;
  }

  // Colon before delimiter or no delimiter = key-value pair
  return false;
}
