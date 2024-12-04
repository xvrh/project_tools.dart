import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

// Replace all absolute imports to relative one
// import 'package:goteam/src/my_widget.dart' => 'import '../my_widget.dart';
String absoluteToRelativeImports(
  String content, {
  required String packageName,
  required String relativePath,
}) {
  var splitRelativePath = p.split(relativePath);
  if (splitRelativePath.firstOrNull != 'lib') {
    throw Exception('relativePath must start with lib/ got $relativePath');
  }
  var thisFilePath = p.posix.joinAll(splitRelativePath.skip(1));

  var newContent = content;

  var unit = parseString(content: content).unit;

  for (var directive
      in unit.directives.reversed.whereType<NamespaceDirective>()) {
    var uriValue = directive.uri.stringValue!;
    var absolutePrefix = 'package:$packageName/';
    if (uriValue.startsWith(absolutePrefix)) {
      var absoluteImportFromLib = uriValue.substring(absolutePrefix.length);
      var relativePath = p.posix.relative(
        absoluteImportFromLib,
        from: p.dirname(thisFilePath),
      );

      var directiveContent = directive.uri.toString().replaceAll(
        uriValue,
        relativePath,
      );

      newContent = newContent.replaceRange(
        directive.uri.offset,
        directive.uri.offset + directive.uri.length,
        directiveContent,
      );
    }
  }

  return newContent;
}
