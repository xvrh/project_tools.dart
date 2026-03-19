import 'dart:io';

/// Returns the root [Directory] of the git repository containing [directory],
/// or `null` if [directory] is not inside a git repository.
Directory? findGitRoot(Directory directory) {
  var result = Process.runSync(
    'git',
    ['rev-parse', '--show-toplevel'],
    workingDirectory: directory.path,
  );
  if (result.exitCode != 0) return null;
  return Directory((result.stdout as String).trim());
}

/// Returns the root [Directory] of the git repository containing [directory]
/// (defaults to [Directory.current]).
///
/// Throws a [StateError] if no git repository is found.
Directory findGitRootOrThrow([Directory? directory]) {
  var dir = directory ?? Directory.current;
  var root = findGitRoot(dir);
  if (root == null) {
    throw StateError('Could not find git root for ${dir.path}');
  }
  return root;
}
