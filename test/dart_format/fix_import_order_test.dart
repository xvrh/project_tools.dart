import 'package:project_tools/src/dart_format/fix_import_order.dart';
import 'package:test/test.dart';

void main() {
  String toWindowsLineSeparator(String input) =>
      input.replaceAll('\n\r', '\n').replaceAll('\n', '\n\r');

  void checkSortImports(String before, String after) {
    expect(sortImports(before), after);
    expect(
      toWindowsLineSeparator(sortImports(toWindowsLineSeparator(before))),
      toWindowsLineSeparator(after),
      reason: 'Windows line separator',
    );
  }

  test('Fix import order 1', () {
    var before = '''
library;
// Some comment
import 'package:yther_package/src/my_widget.dart';
import 'package:other_package/src/my_widget.dart';
import 'my_widget.dart';
import '../my_widget.dart';
import 'colors/colors.dart';

var a = 1;
''';
    var after = '''
library;
import 'package:other_package/src/my_widget.dart';
// Some comment
import 'package:yther_package/src/my_widget.dart';
import '../my_widget.dart';
import 'colors/colors.dart';
import 'my_widget.dart';

var a = 1;
''';

    checkSortImports(before, after);
  });

  test('Fix import order 2', () {
    var before = '''
// Library comment
library;
// Some comment
import 'package:yther_package/src/my_widget.dart';
import 'package:other_package/src/my_widget.dart';
import 'my_widget.dart';
import '../my_widget.dart' show y;
export 'my_widget.dart' show z;
import 'colors/colors.dart';
import 'dart:core';

var a = 1;
''';
    var after = '''
// Library comment
library;
import 'dart:core';
import 'package:other_package/src/my_widget.dart';
// Some comment
import 'package:yther_package/src/my_widget.dart';
import '../my_widget.dart' show y;
import 'colors/colors.dart';
import 'my_widget.dart';

export 'my_widget.dart' show z;

var a = 1;
''';

    checkSortImports(before, after);
  });

  test("Don't touch attributes with new line", () {
    var before = '''
// Some comment
@TestOn()

import 'my_widget.dart';
import 'dart:core';
''';
    var after = '''
// Some comment
@TestOn()

import 'dart:core';
import 'my_widget.dart';
''';

    checkSortImports(before, after);
  });

  test('Reorder attribute if no new line', () {
    var before = '''
// Some comment
@TestOn()
import 'my_widget.dart';
import 'dart:core';
''';
    var after = '''
import 'dart:core';
// Some comment
@TestOn()
import 'my_widget.dart';
''';

    checkSortImports(before, after);
  });

  test("Don't reorder comment if new line", () {
    var before = '''
// Some comment

import 'my_widget.dart';
import 'dart:core';
''';
    var after = '''
// Some comment

import 'dart:core';
import 'my_widget.dart';
''';

    checkSortImports(before, after);
  });

  test('Reorder comment if no new line', () {
    var before = '''
// Some comment
import 'my_widget.dart';
import 'dart:core';
''';
    var after = '''
import 'dart:core';
// Some comment
import 'my_widget.dart';
''';

    checkSortImports(before, after);
  });
  test('Reorder single import', () {
    var before = '''
import 'dart:core';
''';
    var after = '''
import 'dart:core';
''';

    checkSortImports(before, after);
  });

  test('Reorder single import with comment', () {
    var before = '''
// Some comment
import 'dart:core';
''';
    var after = '''
// Some comment
import 'dart:core';
''';

    checkSortImports(before, after);
  });

  test('Reorder single import with comment and space', () {
    var before = '''
// Some comment

import 'dart:core';
''';
    var after = '''
// Some comment

import 'dart:core';
''';

    checkSortImports(before, after);
  });

  test('Reorder parts', () {
    var before = '''
// Some comment

import 'dart:core';
// Other comment
part 'xz.dart'; /* comment */
part 'ab.dart';
''';
    var after = '''
// Some comment

import 'dart:core';

part 'ab.dart';
// Other comment
part 'xz.dart'; /* comment */
''';

    checkSortImports(before, after);
  });

  test('Reorder export with clauses', () {
    var before = '''
// Some comment

export 'dart:core' show double;
export 'dart:async' 
  show x, y;
import 'dart:core';
''';
    var after = '''
// Some comment

import 'dart:core';

export 'dart:async' 
  show x, y;
export 'dart:core' show double;
''';

    checkSortImports(before, after);
  });

  test('Keep comment on the same line', () {
    var before = '''
import 'dart:c';
import 'dart:a1'; // 1
import 'dart:a2'; // 2
import 'dart:b'; /* Some comment */

var a = 1;
''';
    var after = '''
import 'dart:a1'; // 1
import 'dart:a2'; // 2
import 'dart:b'; /* Some comment */
import 'dart:c';

var a = 1;
''';

    checkSortImports(before, after);
  });

  test('Handle imports on the same line', () {
    var before = '''
import 'dart:c';import 'dart:a';

var a = 1;
''';
    var after = '''
import 'dart:a';
import 'dart:c';

var a = 1;
''';

    checkSortImports(before, after);
  });

  test('Handle imports on the same line with inbetween comment', () {
    var before = '''
import 'dart:c';/* cc */import 'dart:a';

var a = 1;
''';
    var after = '''
/* cc */import 'dart:a';
import 'dart:c';

var a = 1;
''';

    checkSortImports(before, after);
  });
}
