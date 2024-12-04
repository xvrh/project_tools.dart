import 'dart:io';
import 'package:dart_style/dart_style.dart';
import 'package:project_tools/project_tools.dart';

void main() {
  var formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );
  for (var project in DartProject.find(Directory.current)) {
    for (var modifiedFile in formatProject(project, formatter)) {
      print(
        'Formatted: ${modifiedFile.project.packageName}:'
        '${modifiedFile.relativePath}',
      );
    }
  }
}
