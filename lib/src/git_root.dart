import 'dart:io';
import 'package:path/path.dart' as p;

// Alternative: git rev-parse --show-toplevel
Directory? findGitRoot(Directory directory) {
  while (true) {
    if (directory
        .listSync()
        .whereType<Directory>()
        .any((d) => p.basename(d.path) == '.git')) {
      return directory;
    }

    var parent = directory.parent;
    if (parent.path == directory.path) {
      return null;
    }

    directory = parent;
  }
}

Directory findGitRootOrThrow() {
  var directory = Directory.current;
  var root = findGitRoot(directory);
  if (root == null) {
    throw StateError('Could not find git root for ${directory.path}');
  }
  return root;
}
