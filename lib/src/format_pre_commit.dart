import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'format.dart';
import 'dart_project.dart';
import 'git_root.dart';

/// Format the changed file in git.
/// This script should be configured as a pre-commit git hook (see CONTRIBUTING.md)
Future<List<ProjectFile>> formatModifiedGitFiles() async {
  var gitRoot = findGitRootOrThrow();
  var projects = DartProject.find(gitRoot);
  projects.sort((p1, p2) => p2.path.length.compareTo(p1.path.length));
  var changedDartFiles = <String, ProjectFile>{};

  var result = Process.runSync('git', ['diff', '--cached', '--name-status']);
  for (var line in LineSplitter.split(result.stdout.toString())) {
    var split = line.split('\t');
    var operation = split[0];
    var changedPath = path.join(gitRoot.path, split.last);

    if (changedPath.endsWith('.dart') && operation != 'D') {
      var file = projects.findFile(changedPath);
      if (file != null) {
        changedDartFiles[changedPath] = file;
      }
    }
  }

  var modifiedFiles = <ProjectFile>[];

  for (var file in changedDartFiles.values) {
    var modified = formatFile(file);
    if (modified) {
      modifiedFiles.add(file);
    }
  }

  if (modifiedFiles.isNotEmpty) {
    // Leave some to time to the file system.
    await Future.delayed(const Duration(seconds: 1));
  }

  for (var file in modifiedFiles) {
    var rootRelative = path.join(file.project.path, file.relativePath);
    Process.runSync('git', ['add', rootRelative]);
  }
  return modifiedFiles;
}
