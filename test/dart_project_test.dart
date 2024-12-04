import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:project_tools/project_tools.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test('findDartProjects', () async {
    await d.dir('repo', [
      d.file('readme.md'),
      d.dir('project', [
        d.file('pubspec.yaml', 'name: project'),
        d.dir('project3', [d.file('pubspec.yaml', 'name: project3')]),
      ]),
      d.dir('project2', [d.file('pubspec.yaml', 'name: project2')]),
    ]).create();

    var files = DartProject.find(Directory(p.join(d.sandbox, 'repo')));
    expect(
      files.map((f) => f.relativePath),
      unorderedEquals([
        p.join('project'),
        p.join('project', 'project3'),
        p.join('project2'),
      ]),
    );
    expect(
      files.map((f) => f.path),
      unorderedEquals([
        p.join(d.sandbox, 'repo', 'project'),
        p.join(d.sandbox, 'repo', 'project', 'project3'),
        p.join(d.sandbox, 'repo', 'project2'),
      ]),
    );
  });

  test('findDartProjects root', () async {
    await d.dir('project', [d.file('pubspec.yaml', 'name: project')]).create();

    var files = DartProject.find(Directory(p.join(d.sandbox, 'project')));
    expect(
      files.map((f) => f.path),
      unorderedEquals([p.join(d.sandbox, 'project')]),
    );
  });

  test('new DartProject', () async {
    await d.dir('repo', [d.file('pubspec.yaml', 'name: project')]).create();

    var project = DartProject(Directory(p.join(d.sandbox, 'repo')));
    expect(project.packageName, 'project');
    expect(project.path, p.join(d.sandbox, 'repo'));
    expect(project.relativePath, '');
    expect(project.useFlutter, false);
  });

  test('DartProject.listFiles should exclude sub projects', () async {
    await d.dir('repo', [
      d.file('pubspec.yaml', 'name: project'),
      d.file('file.txt'),
      d.dir('project', [d.file('pubspec.yaml', 'name: sub_project')]),
      d.dir('lib', [d.file('main.dart')]),
    ]).create();

    var project = DartProject(Directory(p.join(d.sandbox, 'repo')));
    var files = project.listFiles().map((f) => f.normalizedRelativePath);
    expect(
      files,
      unorderedEquals(['file.txt', 'pubspec.yaml', 'lib/main.dart']),
    );
  });

  test('DartProject.listFiles take root .gitignore into account', () async {
    await d.dir('repo', [
      d.file('.gitignore', '_*'),
      d.dir('project', [
        d.file('pubspec.yaml', 'name: project'),
        d.file('file.txt'),
        d.dir('project', [d.file('pubspec.yaml', 'name: sub_project')]),
        d.dir('_lib', [d.file('main.dart')]),
      ]),
    ]).create();

    var project = DartProject(
      Directory(p.join(d.sandbox, 'repo', 'project')),
      gitRoot: Directory(p.join(d.sandbox, 'repo')),
    );
    var files = project.listFiles().map((f) => f.normalizedRelativePath);
    expect(files, unorderedEquals(['file.txt', 'pubspec.yaml']));
  });

  test('Find file in projects with relative', () async {
    await d.dir('repo', [
      d.file('pubspec.yaml', 'name: project'),
      d.file('file.txt'),
      d.dir('project', [
        d.file('pubspec.yaml', 'name: sub_project'),
        d.file('file.txt'),
        d.dir('project', [
          d.file('pubspec.yaml', 'name: sub_sub_project'),
          d.file('file.txt'),
        ]),
      ]),
    ]).create();

    var projects = DartProject.find(Directory(p.join(d.sandbox)));
    var file = projects.findFile('repo/project/file.txt')!;
    expect(file.project.packageName, 'sub_project');
  });

  test('Find file in projects with absolute', () async {
    await d.dir('repo', [
      d.file('pubspec.yaml', 'name: project'),
      d.file('file.txt'),
      d.dir('project', [
        d.file('pubspec.yaml', 'name: sub_project'),
        d.file('file.txt'),
        d.dir('project', [
          d.file('pubspec.yaml', 'name: sub_sub_project'),
          d.file('file.txt'),
        ]),
      ]),
    ]).create();

    var projects = DartProject.find(Directory(p.join(d.sandbox)));
    var file = projects.findFile(p.join(d.sandbox, 'repo/project/file.txt'))!;
    expect(file.project.packageName, 'sub_project');
  });
}
