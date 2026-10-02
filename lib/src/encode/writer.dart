import '../types.dart';
import '../utilities/constants.dart';

/// Line writer for building TOON output with proper indentation.
class LineWriter {
  final List<String> _lines = [];
  final String _indentationString;

  LineWriter(int indentSize) : _indentationString = ' ' * indentSize {
    if (indentSize <= 0) {
      throw ArgumentError('indentSize must be positive');
    }
  }

  void push(Depth depth, String content) {
    final indent = _indentationString * depth;
    _lines.add('$indent$content');
  }

  void pushListItem(Depth depth, String content) {
    push(depth, '$listItemPrefix$content');
  }

  @override
  String toString() {
    return _lines.join('\n');
  }
}
