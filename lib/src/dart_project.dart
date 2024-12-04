import 'dart:io';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'git_root.dart';
import 'list_files.dart' as list_files;

export 'list_files.dart' show FilePath;

class _ProjectLocation {
  final Directory gitRoot;
  final Directory root;
  final Directory directory;

  _ProjectLocation(this.root, this.gitRoot, this.directory);

  String get path => directory.path;

  String get relativePath {
    var path = p.normalize(p.relative(directory.path, from: root.path));
    if (path == '.') {
      path = '';
    }
    return path;
  }
}

class DartProject {
  final _ProjectLocation _location;
  final YamlMap pubspec;

  DartProject._(this._location) : pubspec = _loadPubspec(_location.path);

  factory DartProject(Directory directory, {Directory? gitRoot}) {
    return DartProject._(
      _ProjectLocation(directory, gitRoot ?? directory, directory),
    );
  }

  static List<DartProject> find(Directory root, {Directory? gitRoot}) {
    var paths = <DartProject>[];

    for (var file in list_files.findFilesByName(root, 'pubspec.yaml')) {
      var directory = file.parent;
      paths.add(
        DartProject._(
          _ProjectLocation(
            root,
            gitRoot ?? findGitRoot(root) ?? root,
            directory,
          ),
        ),
      );
    }

    return paths;
  }

  String get packageName => pubspec['name'] as String;

  bool get useFlutter {
    var environment = pubspec['environment'] as YamlMap?;
    if (environment != null && environment.containsKey('flutter')) {
      return true;
    }
    var dependencies = pubspec['dependencies'] as YamlMap?;
    if (dependencies != null && dependencies.containsKey('flutter')) {
      return true;
    }
    return false;
  }

  Directory get directory => _location.directory;

  String get path => _location.path;

  String get relativePath => _location.relativePath;

  static YamlMap _loadPubspec(String projectRoot) {
    var pubspecContent =
        File(p.join(projectRoot, 'pubspec.yaml')).readAsStringSync();
    return loadYaml(pubspecContent) as YamlMap;
  }

  List<ProjectFile> listFiles({Directory? gitRoot}) {
    gitRoot ??= _location.gitRoot;

    return list_files
        .listFiles(
          directory,
          gitRoot: gitRoot,
          shouldEnterDirectory: (dir) {
            var hasPubspec = dir.contents.any(
              (e) => e.path.endsWith('pubspec.yaml'),
            );
            return !hasPubspec;
          },
        )
        .map((f) => ProjectFile(this, f))
        .toList();
  }

  List<ProjectFile> get dartFiles {
    return listFiles().where((f) => f.filePath.path.endsWith('.dart')).toList();
  }

  @override
  String toString() => 'DartProject(name: $packageName, path: $path)';
}

class ProjectFile {
  final DartProject project;
  final list_files.FilePath filePath;

  ProjectFile(this.project, this.filePath);

  String get relativePath => filePath.relativePath;
  String get normalizedRelativePath => filePath.normalizedRelativePath;

  File get file => filePath.file;

  String get path => file.path;

  @override
  String toString() => 'DartFile($file)';
}

extension DartProjectListExtension on List<DartProject> {
  ProjectFile? findFile(String path) {
    var project = sortedBy<num>(
      (e) => e.relativePath.length,
    ).reversed.firstWhereOrNull((project) {
      var pathToCompare = project.relativePath;
      if (p.isAbsolute(path)) {
        pathToCompare = project.path;
      }
      return p.isWithin(pathToCompare, path);
    });

    if (project != null) {
      var relativePath = p.relative(path, from: project.relativePath);
      var file = ProjectFile(
        project,
        list_files.FilePath(
          File(path),
          root: project.directory,
          splitRelativePath: p.split(relativePath),
        ),
      );
      return file;
    }
    return null;
  }
}
