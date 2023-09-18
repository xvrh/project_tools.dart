import 'dart:io';
import 'package:project_tools/format.dart';

void main() {
  for (var project in DartProject.find(Directory.current)) {
    for (var modifiedFile in formatProject(project)) {
      print('Formatted: ${modifiedFile.project.packageName}:'
          '${modifiedFile.relativePath}');
    }
  }
}
