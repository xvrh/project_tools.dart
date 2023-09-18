import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../repository_root.dart';
import 'pubspec_finder.dart';

List<DartProject> getDartProjects(String root) {
  var paths = <DartProject>[];

  for (var file in findPubspecs(Directory(root))) {
    var relativePath = p.relative(file.path, from: root);
    if (p
        .split(relativePath)
        .any((part) => part.startsWith('_') || part.startsWith('.'))) {
      continue;
    }

    paths.add(DartProject(p.normalize(file.parent.absolute.path)));
  }

  return paths;
}

DartProject? getContainingProject(String currentPath) {
  Directory dir;
  if (FileSystemEntity.typeSync(currentPath) == FileSystemEntityType.file) {
    dir = File(currentPath).parent;
  } else {
    dir = Directory(currentPath);
  }

  while (true) {
    if (dir.listSync(followLinks: false).any((r) =>
        r is File && p.basename(r.path).toLowerCase() == 'pubspec.yaml')) {
      return DartProject(dir.path);
    }
    var parent = dir.parent;
    if (dir.path == parent.path) {
      return null;
    }

    dir = parent;
  }
}

/// Retourne les sous-projets ou le projet qui contient le dossier cible.
List<DartProject> getSubOrContainingProjects(String root) {
  var projects = getDartProjects(root);
  if (projects.isEmpty) {
    var containingProject = getContainingProject(root);
    return [if (containingProject != null) containingProject];
  } else {
    return projects;
  }
}

class DartProject {
  final Directory directory;
  final YamlMap pubspec;

  DartProject(String path)
      : directory = Directory(path).absolute,
        pubspec = _loadPubspec(path);

  static DartProject fromRoot(String path) =>
      DartProject(p.join(repositoryRoot, path));

  String get packageName => pubspec['name'] as String;

  bool get useFlutter {
    var environment = pubspec['environment'] as YamlMap?;
    if (environment != null) {
      return environment.containsKey('flutter');
    }
    return false;
  }

  String get path => directory.path;

  String get relativePath => p.relative(path, from: repositoryRoot);

  static YamlMap _loadPubspec(String projectRoot) {
    var pubspecContent =
        File(p.join(projectRoot, 'pubspec.yaml')).readAsStringSync();
    return loadYaml(pubspecContent) as YamlMap;
  }

  List<DartFile> getDartFiles() {
    var files = <DartFile>[];
    _visitDirectory(Directory(path), files, isRoot: true);
    return files;
  }

  void _visitDirectory(Directory directory, List<DartFile> files,
      {bool isRoot = true}) {
    var directoryContent = directory.listSync();

    // On ne visite pas les sous dossiers qui contiennent un autre package
    if (!isRoot &&
        directoryContent
            .any((f) => f is File && f.path.endsWith('pubspec.yaml'))) return;

    for (var entity in directoryContent) {
      if (entity is File && entity.path.endsWith('.dart')) {
        var absoluteFile = entity.absolute;

        files.add(DartFile(this, absoluteFile));
      } else if (entity is Directory) {
        var dirName = p.basename(entity.path);
        if (!const ['android', 'ios', 'Pods', 'build', 'cdk.out']
                .contains(dirName) &&
            !dirName.startsWith('_') &&
            !dirName.startsWith('.')) {
          _visitDirectory(entity, files, isRoot: false);
        }
      }
    }
  }

  @override
  String toString() => 'DartProject(name: $packageName, path: $path)';
}

class DartFile {
  final DartProject project;
  final File file;
  final String relativePath;

  DartFile(this.project, this.file)
      : relativePath = p.relative(file.absolute.path, from: project.path);

  String get path => file.path;

  String get normalizedRelativePath => relativePath.replaceAll(r'\', '/');

  @override
  String toString() => 'DartFile($file)';
}
