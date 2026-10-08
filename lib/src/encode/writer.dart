import '../utilities/constants.dart';

class LineWriter {
  final List<String> _lines = [];
  final String _indentationString;

  LineWriter(int indentSize) : _indentationString = ' ' * indentSize;

  void push(int depth, String content) {
    final indent = _indentationString * depth;
    _lines.add('$indent$content');
  }

  void pushListItem(int depth, String content) {
    push(depth, '$listItemPrefix$content');
  }

  @override
  String toString() {
    return _lines.join('\n');
  }
}
