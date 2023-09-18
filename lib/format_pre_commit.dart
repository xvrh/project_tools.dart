import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;
import 'package:project_tools/src/dart_project.dart';

/// Format the changed file in git.
/// This script should be configured as a pre-commit git hook (see CONTRIBUTING.md)
Future<void> formatModifiedGitFiles(Directory gitRoot) async {
  var projects = DartProject.find(gitRoot);
  projects.sort((p1, p2) => p2.path.length.compareTo(p1.path.length));
  var changedDartFiles = <String, ProjectFile>{};

  var result = Process.runSync('git', ['diff', '--cached', '--name-status']);
  for (var line in LineSplitter.split(result.stdout.toString())) {
    var split = line.split('\t');
    var operation = split[0];
    var changedPath = path.join(repositoryRoot, split.last);

    if (changedPath.endsWith('.dart') && operation != 'D') {
      var project = projects.firstWhereOrNull(
          (DartProject project) => path.isWithin(project.path, changedPath));
      if (project != null) {
        var file = ProjectFile(
            project, FilePath(File(changedPath), root: project.directory));
        changedDartFiles[changedPath] = file;
      }
    }
  }

  print('Files to check: ${changedDartFiles.length}');

  var dartFileToReadToIndex = <ProjectFile>{};

  for (var file in changedDartFiles.values) {
    var modified = fixFile(file);
    if (modified) {
      dartFileToReadToIndex.add(file);
    }
  }

  if (dartFileToReadToIndex.isNotEmpty) {
    // Leave some to time to the file system.
    await Future.delayed(const Duration(seconds: 1));
  }

  print(
      'prepare_submit git hook modified ${dartFileToReadToIndex.length} file(s) before commit');
  for (var file in dartFileToReadToIndex) {
    var rootRelative = path.join(file.project.path, file.relativePath);
    print('prepare_submit: $rootRelative');
    Process.runSync('git', ['add', rootRelative]);
  }
}
