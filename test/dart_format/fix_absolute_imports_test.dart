import 'package:project_tools/src/dart_format/fix_absolute_imports.dart';
import 'package:test/test.dart';

void main() {
  test('Fix absolute imports', () {
    var before = '''
library;
// Some comment
import 'package:other_package/src/my_widget.dart';
import 'package:my_package/src/ui/my_widget.dart';
import 'package:my_package/src/my_widget.dart';
import 'package:my_package/src/ui/colors/colors.dart';

var a = 1;
''';
    var after = '''
library;
// Some comment
import 'package:other_package/src/my_widget.dart';
import 'my_widget.dart';
import '../my_widget.dart';
import 'colors/colors.dart';

var a = 1;
''';

    expect(
        absoluteToRelativeImports(before,
            packageName: 'my_package', relativePath: 'lib/src/ui/widget.dart'),
        after);
  });

  test('Only works inside lib', () {
    expect(
        () => absoluteToRelativeImports('',
            packageName: 'my_package', relativePath: 'src/ui/widget.dart'),
        throwsA((e) => '$e'.contains('lib/')));
  });
}
