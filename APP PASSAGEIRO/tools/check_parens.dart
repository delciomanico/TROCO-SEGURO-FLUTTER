import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart check_parens.dart <file>');
    exit(1);
  }
  final file = File(args[0]);
  final lines = file.readAsLinesSync();
  var openParen = 0;
  var openBrace = 0;
  var openBracket = 0;
  var parenStack = <int>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (var ch in line.runes) {
      final c = String.fromCharCode(ch);
      if (c == '(') {
        openParen++;
        parenStack.add(i + 1);
      } else if (c == ')') {
        openParen--;
        if (parenStack.isNotEmpty) {
          parenStack.removeLast();
        }
      } else if (c == '{') {
        openBrace++;
      } else if (c == '}') {
        openBrace--;
      } else if (c == '[') {
        openBracket++;
      } else if (c == ']') {
        openBracket--;
      }
    }
    if (openParen < 0 || openBrace < 0 || openBracket < 0) {
      print('Mismatch at line ${i + 1}: paren=$openParen brace=$openBrace bracket=$openBracket');
      print(line);
      exit(0);
    }
    // Print context when parentheses count changes significantly
    if (openParen > 0 || openBrace > 0 || openBracket > 0) {
      print('Line ${i + 1}: paren=$openParen brace=$openBrace bracket=$openBracket -> ${line.trim()}');
    }
  }
  print('Final counts: paren=$openParen brace=$openBrace bracket=$openBracket');
  if (parenStack.isNotEmpty) {
    print('Unmatched "(" found at lines: ${parenStack.join(', ')}');
    for (var ln in parenStack) {
      print('$ln: ${lines[ln - 1].trim()}');
    }
  }
}
