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
  final List<_GitIgnore> rootIgnores;

  _ListContext({
    required this.enterDirectoryPredicate,
    required this.gitRoot,
    required this.rootIgnores,
  });
}

class _GitIgnore {
  final String directory;
  final Ignore _ignore;

  _GitIgnore._(this.directory, this._ignore);

  static _GitIgnore? read(Directory directory) {
    var file = File(p.join(directory.path, '.gitignore'));
    if (!file.existsSync()) return null;
    return _GitIgnore._(directory.path, Ignore([file.readAsStringSync()]));
  }

  IgnoreMatch match(String path, {required bool isDirectory}) {
    var relativePath = p.relative(path, from: directory).replaceAll(r'\', '/');
    return _ignore.match(isDirectory ? '$relativePath/' : relativePath);
  }
}

class _Directory {
  final _Directory? parent;
  final Directory directory;
  final _ListContext context;

  /// Every .gitignore that applies to this directory's entries, outermost
  /// first.
  final List<_GitIgnore> _gitIgnores;

  _Directory(this.directory, {this.parent, required this.context})
    : _gitIgnores = [
        ...parent?._gitIgnores ?? context.rootIgnores,
        if (_GitIgnore.read(directory) case var gitIgnore?) gitIgnore,
      ];

  String get rootPath => root.path;

  Directory get root => parent?.root ?? directory;

  Iterable<FilePath> visit(List<FileSystemEntity> files) sync* {
    for (var file in files) {
      if (file is File) {
        if (!_ignores(file.path, isDirectory: false)) {
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

        if (!_ignores(file.path, isDirectory: true)) {
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

  /// As git decides: the deepest .gitignore with a rule for [path] wins, and
  /// nothing under an ignored directory is asked about, since [visit] does not
  /// enter one.
  bool _ignores(String path, {required bool isDirectory}) {
    for (var gitIgnore in _gitIgnores.reversed) {
      var match = gitIgnore.match(path, isDirectory: isDirectory);
      if (match != IgnoreMatch.none) return match == IgnoreMatch.ignored;
    }
    return false;
  }
}

/// The .gitignore files between [gitRoot] and [root]'s parent, outermost
/// first.
List<_GitIgnore> _upperGitIgnores(Directory root, Directory gitRoot) {
  if (p.equals(root.path, gitRoot.path)) return [];

  if (!p.isWithin(gitRoot.path, root.path)) {
    throw Exception(
      'Git root (${gitRoot.path}) is not an ancestor of ${root.path}',
    );
  }
  var ignores = <_GitIgnore>[];
  var current = root.parent;
  while (true) {
    if (_GitIgnore.read(current) case var gitIgnore?) {
      ignores.add(gitIgnore);
    }
    // `p.equals`, not `==`: one directory has more than one spelling. Git
    // prints `C:/Users/…` on Windows where `dart:io` says `C:\Users\…`, and a
    // trailing separator is a spelling too. Compared as strings, the walk
    // never met the git root and sat at the filesystem root forever.
    if (p.equals(current.path, gitRoot.path)) {
      break;
    }
    var parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }

  return ignores.reversed.toList();
}
