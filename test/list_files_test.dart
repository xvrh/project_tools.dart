import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:project_tools/project_tools.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test('listFiles', () async {
    await d.dir('parent', [
      d.file('outside.md'),
      d.dir('repo', [
        d.file('readme.md'),
        d.dir('project', [d.file('pubspec.yaml')]),
      ]),
    ]).create();

    var files =
        listFiles(Directory(p.join(d.sandbox, 'parent', 'repo'))).toList();
    expect(
      files.map((f) => f.path),
      unorderedEquals([
        p.join(d.sandbox, 'parent', 'repo', 'readme.md'),
        p.join(d.sandbox, 'parent', 'repo', 'project', 'pubspec.yaml'),
      ]),
    );
  });

  test('listFiles with directory predicate', () async {
    await d.dir('root', [
      d.file('outside.md'),
      d.dir('project', [
        d.file('readme.md'),
        d.file('pubspec.yaml'),
        d.dir('project2', [d.file('readme.md'), d.file('pubspec.yaml')]),
      ]),
    ]).create();

    var files = listFiles(
      Directory(d.sandbox),
      shouldEnterDirectory: (dir) {
        var hasSubProject =
            dir.depth > 2 &&
            dir.contents.any((e) => e.path.endsWith('pubspec.yaml'));
        return !hasSubProject;
      },
    );
    expect(
      files.map((f) => f.path),
      unorderedEquals([
        p.join(d.sandbox, 'root', 'outside.md'),
        p.join(d.sandbox, 'root', 'project', 'readme.md'),
        p.join(d.sandbox, 'root', 'project', 'pubspec.yaml'),
      ]),
    );
  });

  test('listPaths', () async {
    await d.dir('parent', [
      d.file('outside.md'),
      d.dir('repo', [
        d.file('readme.md'),
        d.dir('project', [d.file('pubspec.yaml')]),
      ]),
    ]).create();

    var files = listPaths(Directory('${d.sandbox}/parent/repo'));
    expect(files.length, equals(2));
    expect(
      files,
      unorderedEquals(['readme.md', p.join('project', 'pubspec.yaml')]),
    );
  });

  test('listPaths follow .gitignore rules', () async {
    await d.dir('parent', [
      d.file('outside.md'),
      d.dir('repo', [
        d.file('.gitignore', '*.md'),
        d.file('readme.md'),
        d.dir('project', [
          d.file('readme.md'),
          d.file('.gitignore', '_*'),
          d.file('pubspec.yaml'),
          d.file('_ignore_me.txt'),
          d.dir('lib', [
            d.file('file.dart'),
            d.file('readme.md'),
            d.file('_ignore_me.txt'),
          ]),
        ]),
      ]),
    ]).create();

    var files = listPaths(Directory(p.join(d.sandbox, 'parent', 'repo')));
    expect(
      files,
      unorderedEquals([
        '.gitignore',
        p.join('project', 'pubspec.yaml'),
        p.join('project', '.gitignore'),
        p.join('project', 'lib', 'file.dart'),
      ]),
    );
  });

  test('findFilesByName', () async {
    await d.dir('parent', [
      d.file('outside.md'),
      d.dir('repo', [
        d.file('readme.md'),
        d.dir('project', [d.file('pubspec.yaml')]),
      ]),
    ]).create();

    var files = findFilesByName(Directory(d.sandbox), 'pubspec.yaml');
    expect(files.length, equals(1));
    expect(
      files.map((f) => f.path),
      unorderedEquals([
        p.join(d.sandbox, 'parent', 'repo', 'project', 'pubspec.yaml'),
      ]),
    );
  });

  test('findPathByName', () async {
    await d.dir('parent', [
      d.file('outside.md'),
      d.file('.gitignore', '_*'),
      d.dir('repo', [
        d.file('readme.md'),
        d.dir('_project', [d.file('pubspec.yaml')]),
        d.dir('project', [d.file('pubspec.yaml')]),
      ]),
    ]).create();

    var files = findPathsByName(Directory(d.sandbox), 'pubspec.yaml');
    expect(files.length, equals(1));
    expect(
      files,
      unorderedEquals([p.join('parent', 'repo', 'project', 'pubspec.yaml')]),
    );
  });

  test(
    '.gitignore are only taken into account starting from root parameter',
    () async {
      await d.dir('parent', [
        d.file('outside.md'),
        d.file('.gitignore', '_*'),
        d.dir('repo', [
          d.file('readme.md'),
          d.dir('_project', [d.file('pubspec.yaml')]),
          d.dir('project', [d.file('pubspec.yaml')]),
        ]),
      ]).create();

      var files = findPathsByName(
        Directory(p.join(d.sandbox, 'parent', 'repo')),
        'pubspec.yaml',
      );
      expect(files.length, equals(2));
      expect(
        files,
        unorderedEquals([
          p.join('project', 'pubspec.yaml'),
          p.join('_project', 'pubspec.yaml'),
        ]),
      );
    },
  );

  test('listFiles with gitRoot', () async {
    await d.dir('parent', [
      d.file('outside.md'),
      d.file('.gitignore', '_*'),
      d.dir('repo', [
        d.file('.gitignore', '.*'),
        d.dir('_project', [d.file('pubspec.yaml')]),
        d.dir('.project', [d.file('pubspec.yaml')]),
        d.dir('project', [d.file('pubspec.yaml')]),
      ]),
    ]).create();

    var files =
        listFiles(
          Directory(p.join(d.sandbox, 'parent', 'repo')),
          gitRoot: Directory(d.sandbox),
        ).map((f) => f.relativePath).toList();
    expect(files, unorderedEquals([p.join('project', 'pubspec.yaml')]));
  });
}
