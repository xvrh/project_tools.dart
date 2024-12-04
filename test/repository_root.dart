import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:project_tools/project_tools.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test('findGitRoot exist', () async {
    await d.dir('parent', [
      d.dir('repo', [
        d.file('readme.md'),
        d.dir('.git', [d.file('config')]),
        d.dir('project', [d.file('pubspec.yaml')]),
      ]),
    ]).create();

    var root =
        findGitRoot(Directory(p.join(d.sandbox, 'parent', 'repo', 'project')))!;
    expect(root.path, p.join(d.sandbox, 'parent', 'repo'));

    var root2 = findGitRoot(Directory(p.join(d.sandbox, 'parent', 'repo')))!;
    expect(root2.path, p.join(d.sandbox, 'parent', 'repo'));
  });

  test('findGitRoot not exist', () async {
    await d.dir('parent', [
      d.dir('repo', [
        d.file('readme.md'),
        d.dir('project', [d.file('pubspec.yaml')]),
      ]),
    ]).create();

    expect(findGitRoot(Directory('${d.sandbox}/parent/repo/project')), isNull);
  });
}
