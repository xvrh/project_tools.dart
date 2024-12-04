import 'dart:io';
import 'package:collection/collection.dart';
import 'package:github/github.dart';
import 'package:markdown/markdown.dart';
import 'package:process_runner/process_runner.dart';
import 'package:pub_semver/pub_semver.dart';
import 'changelog.dart';
import 'upgrade_runner.dart';

class GithubDependabot {
  final _process = ProcessRunner(printOutputDefault: true);
  final String repository;
  final Authentication githubAuthentication;
  final String branch;

  GithubDependabot({
    String? repository,
    Authentication? githubAuthentication,
    String? branch,
  }) : repository = repository ?? Platform.environment['GITHUB_REPOSITORY']!,
       githubAuthentication =
           githubAuthentication ?? findAuthenticationFromEnvironment(),
       branch = branch ?? _autoBranchName();

  static String _autoBranchName() {
    var now = DateTime.now();
    return 'upgrade_deps/${now.toIso8601String().split('.').first.replaceAll(':', '')}';
  }

  Future<void> switchToBranch() async {
    await _process.runProcess(['git', 'checkout', '-b', branch]);
  }

  Future<void> commitAndPush(String commitMessage) async {
    await _process.runProcess(['git', 'add', '.']);
    await _process.runProcess(['git', 'commit', '-m', commitMessage]);
    await _process.runProcess([
      'git',
      'push',
      '--set-upstream',
      'origin',
      branch,
    ]);
  }

  Future<void> openPullRequest({
    required String title,
    required String body,
  }) async {
    // Github will not trigger workflow for user GITHUB_TOKEN.
    // We need to use a personal token.
    // https://docs.github.com/en/free-pro-team@latest/actions/reference/events-that-trigger-workflows#triggering-new-workflows-using-a-personal-access-token

    var github = GitHub(auth: githubAuthentication);

    const maxLength = 65000; // Enforced by Github
    if (body.length > maxLength) {
      body = body.substring(0, maxLength);
    }
    await github.pullRequests.create(
      RepositorySlug.full(repository),
      CreatePullRequest(title, branch, 'master', body: body),
    );
    github.client.close();
  }
}

Future<Comment> summaryToGithubComment(
  List<ProjectUpgrade> projects, {
  List<String>? highlightPackages,
  Future<Changelog?> Function(PubUpgrade)? changelogProvider,
  int changelogMaxLength = 400,
}) async {
  var allUpgrades = projects.expand((p) => p.pubUpgrades);
  var breakingCount = allUpgrades.where((u) => u.isBreaking).length;
  var projectsCount = projects.where((p) => p.pubUpgrades.isNotEmpty).length;
  var title =
      '$projectsCount project${projectsCount > 1 ? 's' : ''}, '
      '$allUpgrades upgrades '
      '($breakingCount breaking${breakingCount > 1 ? 's' : ''})';

  var highlightPackagesNullSafe = highlightPackages ?? [];

  var sortedProjects = projects.toList();
  mergeSort<ProjectUpgrade>(
    sortedProjects,
    compare: (a, b) {
      int weight(ProjectUpgrade p) {
        var index = highlightPackagesNullSafe.indexOf(p.project.packageName);
        if (index == -1) {
          return highlightPackagesNullSafe.length;
        }
        return index;
      }

      return weight(a).compareTo(weight(b));
    },
  );

  var body = StringBuffer();
  for (var project in sortedProjects) {
    var breakings = project.pubUpgrades.where((e) => e.isBreaking).length;
    var count = project.pubUpgrades.length;

    body.writeln('### ${project.project.packageName}');

    if (project.pubUpgrades.isNotEmpty) {
      body.writeln('<details>');
      body.writeln(
        '<summary>($count upgrade${count > 1 ? 's' : ''}, $breakings breaking${breakings > 1 ? 's' : ''})</summary>',
      );
      body.writeln('');
      body.writeln('''
Package | Type | Version | Changelog${' &nbsp;' * 30}
---|--- | --- | ---''');
      for (var upgrade in project.pubUpgrades) {
        String title;
        if (upgrade.isHosted) {
          title =
              '[${upgrade.package}](https://pub.dev/packages/${upgrade.package})';
        } else {
          title = upgrade.package;
        }
        var type = upgrade.type.name.toUpperCase();
        if (upgrade.isBreaking) {
          type = '**$type**';
        }
        var changelogColumn = '';
        if (changelogProvider != null) {
          var htmlChangeLog = '';
          var changelog = await changelogProvider(upgrade);

          if (changelog != null) {
            if (changelog.body case var body?) {
              if (body.length > changelogMaxLength) {
                body = body.substring(0, changelogMaxLength);
              }
              htmlChangeLog = markdownToHtml(body);
            }

            changelogColumn =
                '<details>'
                '<summary>[Changelog](${changelog.link})</summary>'
                '$htmlChangeLog'
                '</details>';

            changelogColumn = changelogColumn
                .replaceAll('\n', '')
                .replaceAll('\r', '');
          }
        }

        body.writeln(
          '$title | $type | ${upgrade.from ?? ''} → ${upgrade.to} | $changelogColumn',
        );
      }
      body.writeln('</details>\n');
      body.writeln('');
    }

    if (project.outdated.isNotEmpty) {
      body.writeln('<details>');
      body.writeln('<summary>Outdated: ${project.outdated.length}</summary>');
      body.writeln('');
      body.writeln('''
Package | Current | Resolvable | Latest
---|--- | --- | ---''');
      for (var package in project.outdated) {
        var title =
            '[${package.package}](https://pub.dev/packages/${package.package})';

        String versionOrEmpty(Version? v) => v == null ? '' : '$v';

        body.writeln(
          '$title | '
          '${versionOrEmpty(package.current)} | '
          '${versionOrEmpty(package.resolvable)} | '
          '${versionOrEmpty(package.latest)}',
        );
      }
      body.writeln('</details>');
    }

    for (var podUpdate in project.podUpdates) {
      body.writeln('''
<details>
<summary>${podUpdate.name} Pod update</summary>

```
${podUpdate.diff}
```

</details>        
''');
    }
    body.writeln('');
  }

  return Comment(title, body.toString());
}

class Comment {
  final String title;
  final String body;

  Comment(this.title, this.body);
}
