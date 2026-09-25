import 'dart:convert';
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

  test('listFiles with gitRoot spelled differently from the root', () async {
    await d.dir('parent', [
      d.file('.gitignore', '_*'),
      d.dir('repo', [
        d.dir('_project', [d.file('pubspec.yaml')]),
        d.dir('project', [d.file('pubspec.yaml')]),
      ]),
    ]).create();

    // The directory the walk reaches, with a trailing separator — and on
    // Windows, in the forward slashes git prints. Compared as strings this
    // never matched, and listing never returned.
    var gitRoot = '${p.join(d.sandbox, 'parent')}${p.separator}';
    if (Platform.isWindows) gitRoot = gitRoot.replaceAll(r'\', '/');

    var files =
        listFiles(
          Directory(p.join(d.sandbox, 'parent', 'repo')),
          gitRoot: Directory(gitRoot),
        ).map((f) => f.relativePath).toList();
    expect(files, unorderedEquals([p.join('project', 'pubspec.yaml')]));
  });

  test('anchored rules in a .gitignore above the root', () async {
    await d.dir('repo', [
      d.file(
        '.gitignore',
        '_*\n'
            '!packages/foo/lib/src/_kept.dart\n'
            'packages/foo/secret.txt\n',
      ),
      d.dir('packages', [
        d.dir('foo', [
          d.file('pubspec.yaml'),
          d.file('secret.txt'),
          d.dir('lib', [
            d.dir('src', [
              d.file('a.dart'),
              d.file('_kept.dart'),
              d.file('_scratch.dart'),
            ]),
          ]),
        ]),
      ]),
    ]).create();
    var repo = p.join(d.sandbox, 'repo');
    var package = p.join(repo, 'packages', 'foo');
    _gitInit(repo);

    var files =
        listFiles(
          Directory(package),
          gitRoot: Directory(repo),
        ).map((f) => f.normalizedRelativePath).toList();
    expect(
      files,
      unorderedEquals(['pubspec.yaml', 'lib/src/a.dart', 'lib/src/_kept.dart']),
    );
    expect(files, unorderedEquals(_gitListing(package)));
  });

  test(
    'a deeper .gitignore re-includes what a shallower one ignores',
    () async {
      await d.dir('repo', [
        d.file('.gitignore', '*.log\nbuild/\n'),
        d.file('root.log'),
        d.dir('sub', [
          d.file('.gitignore', '!keep.log\n'),
          d.file('keep.log'),
          d.file('other.log'),
        ]),
        // Nothing re-includes a file whose directory is excluded.
        d.dir('build', [d.file('.gitignore', '!*\n'), d.file('out.txt')]),
      ]).create();
      var repo = p.join(d.sandbox, 'repo');
      _gitInit(repo);

      var files =
          listFiles(
            Directory(repo),
          ).map((f) => f.normalizedRelativePath).toList();
      expect(
        files,
        unorderedEquals(['.gitignore', 'sub/.gitignore', 'sub/keep.log']),
      );
      expect(files, unorderedEquals(_gitListing(repo)));
    },
  );

  test('listFiles ignores .git directory', () async {
    await d.dir('root', [
      d.file('outside.md'),
      d.dir('.git', [d.file('file.dart')]),
    ]).create();

    var files =
        listFiles(
          Directory(p.join(d.sandbox, 'root')),
        ).map((f) => f.relativePath).toList();
    expect(files, unorderedEquals(['outside.md']));
  });
}

void _gitInit(String directory) {
  var result = Process.runSync('git', [
    'init',
    '--quiet',
  ], workingDirectory: directory);
  expect(result.exitCode, 0, reason: '${result.stderr}');
}

/// The files git does not ignore under [directory], relative to it. Only
/// `.gitignore` files count: the repository's info/exclude and the user's
/// global excludes are left out, so the machine cannot change the answer.
List<String> _gitListing(String directory) {
  var result = Process.runSync('git', [
    'ls-files',
    '--others',
    '--exclude-per-directory=.gitignore',
  ], workingDirectory: directory);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return LineSplitter.split(result.stdout as String).toList();
}
