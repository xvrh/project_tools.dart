import 'dart:io';
import 'package:path/path.dart' as p;
import 'ignore/ignore.dart';

typedef EnterDirectoryPredicate = bool Function(DirectoryContext);

class DirectoryContext {
  final Directory directory;
  final List<FileSystemEntity> contents;
  final List<String> splitRelativePath;

  DirectoryContext({
    required this.directory,
    required this.contents,
    required this.splitRelativePath,
  });

  String get name => p.basename(directory.path);

  String get relativePath => p.joinAll(splitRelativePath);

  int get depth => splitRelativePath.length;
}

class FilePath {
  final File file;
  final Directory root;
  final List<String> splitRelativePath;

  FilePath(this.file, {required this.root, required this.splitRelativePath});

  Directory get parent => file.parent;

  String get path => file.path;

  String get relativePath => p.joinAll(splitRelativePath);

  String get normalizedRelativePath => p.posix.joinAll(splitRelativePath);

  String get name => p.basename(file.path);

  @override
  String toString() => 'FilePath($path)';
}

Iterable<FilePath> listFiles(
  Directory root, {
  EnterDirectoryPredicate? shouldEnterDirectory,
  Directory? gitRoot,
}) {
  gitRoot ??= root;

  var gitIgnores = _upperGitIgnores(root, gitRoot);

  return _Directory(
    root,
    context: _ListContext(
      gitRoot: gitRoot,
      enterDirectoryPredicate: shouldEnterDirectory,
      rootIgnores: gitIgnores,
    ),
  ).visit(root.listSync());
}

Iterable<String> listPaths(
  Directory root, {
  EnterDirectoryPredicate? shouldEnterDirectory,
}) {
  return listFiles(
    root,
    shouldEnterDirectory: shouldEnterDirectory,
  ).map((f) => p.relative(f.path, from: root.path));
}

List<FilePath> findFilesByName(Directory root, String fileName) {
  return listFiles(root).where((f) => p.basename(f.path) == fileName).toList();
}

List<String> findPathsByName(Directory root, String fileName) {
  return findFilesByName(
    root,
    fileName,
  ).map((f) => p.relative(f.path, from: root.path)).toList();
}

extension IterableFileExtension on Iterable<File> {
  Iterable<File> within(String relativePath) =>
      where((f) => p.isWithin(relativePath, f.path));
}

class _ListContext {
  final EnterDirectoryPredicate? enterDirectoryPredicate;
  final Directory gitRoot;
  final List<Ignore> rootIgnores;

  _ListContext({
    required this.enterDirectoryPredicate,
    required this.gitRoot,
    required this.rootIgnores,
  });
}

class _Directory {
  final _Directory? parent;
  final Directory directory;
  Ignore? _ignore;
  final _ListContext context;

  _Directory(this.directory, {this.parent, required this.context}) {
    var gitignore = File(p.join(directory.path, '.gitignore'));
    if (gitignore.existsSync()) {
      _ignore = Ignore([gitignore.readAsStringSync()]);
    }
  }

  String get rootPath => root.path;

  Directory get root => parent?.root ?? directory;

  Iterable<FilePath> visit(List<FileSystemEntity> files) sync* {
    for (var file in files) {
      if (file is File) {
        if (!_ignores(file.path)) {
          yield FilePath(
            file,
            root: root,
            splitRelativePath: p.split(p.relative(file.path, from: rootPath)),
          );
        }
      } else if (file is Directory) {
        if (p.basename(file.path) == '.git') {
          continue;
        }

        if (!_ignores('${file.path}/')) {
          var subDirectory = _Directory(file, parent: this, context: context);
          var contents = file.listSync();
          var shouldEnterDirectory = true;
          if (context.enterDirectoryPredicate
              case var enterDirectoryPredicate?) {
            shouldEnterDirectory = enterDirectoryPredicate(
              DirectoryContext(
                directory: file,
                contents: contents,
                splitRelativePath: p.split(
                  p.relative(file.path, from: rootPath),
                ),
              ),
            );
          }
          if (shouldEnterDirectory) {
            yield* subDirectory.visit(contents);
          }
        }
      }
    }
  }

  bool _ignores(String path) {
    var ignored = false;
    var relativePath = p
        .relative(path, from: directory.path)
        .replaceAll(r'\', '/');
    if (_ignore != null) {
      ignored |= _ignore!.ignores(relativePath);
    }
    if (parent != null) {
      ignored |= parent!._ignores(path);
    } else {
      for (var rootIgnore in context.rootIgnores) {
        ignored |= rootIgnore.ignores(relativePath);
      }
    }
    return ignored;
  }
}

List<Ignore> _upperGitIgnores(Directory root, Directory gitRoot) {
  if (root.path == gitRoot.path) return [];

  if (!p.isWithin(gitRoot.path, root.path)) {
    throw Exception(
      'Git root (${gitRoot.path}) is not an ancestor of ${root.path}',
    );
  }
  var ignores = <Ignore>[];
  var current = root.parent;
  while (true) {
    var gitignore = File(p.join(current.path, '.gitignore'));
    if (gitignore.existsSync()) {
      ignores.add(Ignore([gitignore.readAsStringSync()]));
    }
    if (current.path == gitRoot.path) {
      break;
    }
    current = current.parent;
  }

  return ignores;
}
