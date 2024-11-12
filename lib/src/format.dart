import 'package:dart_style/dart_style.dart';
import 'dart_format/fix_absolute_imports.dart';
import 'dart_format/fix_import_order.dart';
import 'dart_project.dart';

export 'dart_project.dart' show DartProject;

Iterable<ProjectFile> formatProject(DartProject project) sync* {
  for (var file in project.dartFiles) {
    if (formatFile(file)) {
      yield file;
    }
  }
}

final _formatter = DartFormatter(
  fixes: StyleFix.all,
  languageVersion: DartFormatter.latestLanguageVersion,
);

bool formatFile(ProjectFile file, {bool reorderImports = false}) {
  final originalContent = file.file.readAsStringSync();
  var content = originalContent;
  try {
    if (reorderImports) {
      if (file.normalizedRelativePath.startsWith('lib/')) {
        content = absoluteToRelativeImports(content,
            packageName: file.project.packageName,
            relativePath: file.relativePath);
      }
      content = sortImports(content);
    }
    content = _formatter.format(content);

    if (content != originalContent) {
      file.file.writeAsStringSync(content);
      return true;
    }
    return false;
  } catch (e) {
    print('Error while formatting ${file.relativePath}.\n$e');
    rethrow;
  }
}
