import 'dart:io';
import 'package:path/path.dart' as p;

class FlutterSdk {
  final String root;

  FlutterSdk(String path) : root = p.canonicalize(path);

  static FlutterSdk get current {
    var sdk = tryFind(Platform.resolvedExecutable);
    if (sdk != null) {
      return sdk;
    }
    throw StateError('Flutter SDK not found. Dart executable: '
        '${Platform.resolvedExecutable}');
  }

  static FlutterSdk? tryFind(String path) {
    if (FileSystemEntity.isDirectorySync(path)) {
      var dir = Directory(path);
      while (dir.existsSync()) {
        var sdk = FlutterSdk(dir.path);
        if (isValid(sdk)) {
          return sdk;
        } else {
          var parent = dir.parent;
          if (parent.path == dir.path) return null;
          dir = parent;
        }
      }
    } else if (FileSystemEntity.isFileSync(path)) {
      return tryFind(File(path).parent.path);
    }
    return null;
  }

  String get flutter =>
      p.join(root, 'bin', 'flutter${Platform.isWindows ? '.bat' : ''}');

  static bool isValid(FlutterSdk sdk) {
    return File(sdk.flutter).existsSync();
  }
}
