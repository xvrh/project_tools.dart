import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'upgrade_runner.dart';

class Changelog {
  final PubUpgrade upgrade;
  final String? body;

  Changelog(this.upgrade, this.body);

  static Future<Changelog?> forPubUpgrade(PubUpgrade upgrade) async {
    if (!upgrade.isHosted) return null;

    var full = await readChangelog(upgrade);
    String? changelog;
    if (full != null) {
      changelog =
          extractChangelogBetweenVersions(full, upgrade.from, upgrade.to);
    }

    return Changelog(upgrade, changelog);
  }

  String get link {
    var versionHash = '${upgrade.to}'
        .replaceAll(RegExp(r'[^0-9a-z]', caseSensitive: false), '');
    return 'https://pub.dev/packages/${upgrade.package}/changelog#$versionHash';
  }
}

Future<String?> readChangelog(PubUpgrade upgrade) async {
  var packageConfig = (await findPackageConfig(upgrade.project.directory))!;
  var packageInfo = packageConfig[upgrade.package]!;
  var filesInPackage = Directory.fromUri(packageInfo.root).listSync();
  var changelog = filesInPackage.whereType<File>().firstWhereOrNull(
      (e) => p.basename(e.path).toUpperCase().startsWith('CHANGELOG.'));
  if (changelog != null) {
    return await changelog.readAsString();
  } else {
    return null;
  }
}

// TODO(xha): enhance this extraction. There are some bug:
// - Try to prioritise version in the title
// - Respect from should be bellow to
// - Fallback to entire changelog if there are several reference to a version
//   and the extraction is not safe.
String extractChangelogBetweenVersions(
    String input, Version? from, Version to) {
  var lines = LineSplitter.split(input).toList();

  var startLine = 0, endLine = lines.length - 1;
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line.contains('$to')) {
      startLine = i;
    }
    if (from != null && line.contains('$from')) {
      endLine = i;
    }
  }

  if (endLine < startLine) {
    var end = startLine;
    startLine = endLine;
    endLine = end;
  }

  if (endLine == startLine) {
    return lines[endLine];
  }

  return lines.getRange(startLine, endLine).join('\n');
}
