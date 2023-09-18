import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

String sortImports(String source) {
  return _sortImports(source, parseString(content: source).unit);
}

String _sortImports(String content, CompilationUnit unit) {
  var imports = <_Directive>[];
  var exports = <_Directive>[];
  var parts = <_Directive>[];

  var minOffset = 0, maxOffset = 0;
  var lastOffset = 0;
  var isFirst = true;
  for (var directive in unit.directives.whereType<UriBasedDirective>()) {
    int offset, length;
    if (isFirst) {
      isFirst = false;

      if (_hasPrecedingNewLine(
          content, directive.firstTokenAfterCommentAndMetadata.offset - 1)) {
        offset = directive.firstTokenAfterCommentAndMetadata.offset;
      } else {
        offset = (directive.metadata.beginToken ?? directive.beginToken)
                .precedingComments
                ?.offset ??
            directive.beginToken.offset;
      }
      length = (directive.endToken.offset + directive.endToken.length) - offset;
      minOffset = offset;
    } else {
      offset = lastOffset;
      length =
          directive.endToken.offset + directive.endToken.length - lastOffset;
    }

    maxOffset = offset + length;
    lastOffset = maxOffset;

    var wholeDirective = _Directive(
        directive, content.substring(offset, offset + length).trim());

    if (directive is ImportDirective) {
      imports.add(wholeDirective);
    } else if (directive is ExportDirective) {
      exports.add(wholeDirective);
    } else {
      parts.add(wholeDirective);
    }
  }

  imports.sort(_compare);
  exports.sort(_compare);
  parts.sort(_compare);

  var contentBefore = content.substring(0, minOffset);
  var reorderedContent = StringBuffer();

  var needPrecedingNewLine = false;
  void writeBlock(List<_Directive> directives) {
    if (needPrecedingNewLine && directives.isNotEmpty) {
      reorderedContent
        ..writeln()
        ..writeln();
    }
    reorderedContent.write(directives.map((d) => d.content).join('\n'));
    if (directives.isNotEmpty) {
      needPrecedingNewLine = true;
    }
  }

  writeBlock(imports);
  writeBlock(exports);
  writeBlock(parts);

  var contentAfter = content.substring(maxOffset);

  var newContent = contentBefore + reorderedContent.toString() + contentAfter;

  return newContent;
}

bool _hasPrecedingNewLine(String content, int offset) {
  var newLineCount = 0;
  while (offset >= 0) {
    var char = content[offset];
    if (char == '\n') {
      ++newLineCount;

      if (newLineCount > 1) {
        return true;
      }
    } else if (char != ' ' && char != '\r') {
      return false;
    }
    --offset;
  }
  return true;
}

int _compare(_Directive directive1, _Directive directive2) {
  var uri1 = directive1.directive.uri.stringValue!;
  var uri2 = directive2.directive.uri.stringValue!;

  if (uri1.contains(':') && !uri2.contains(':')) {
    return -1;
  } else if (!uri1.contains(':') && uri2.contains(':')) {
    return 1;
  } else {
    return uri1.compareTo(uri2);
  }
}

class _Directive {
  final UriBasedDirective directive;
  final String content;

  _Directive(this.directive, this.content);
}
