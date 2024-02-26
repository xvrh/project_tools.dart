import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:process_runner/process_runner.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';
import '../dart_project.dart';

class UpgradeRunner {
  final String dartOrFlutterBinary;

  UpgradeRunner({required this.dartOrFlutterBinary});

  Future<List<ProjectUpgrade>> upgradeProjects(
      List<DartProject> projects) async {
    var upgrades = <ProjectUpgrade>[];
    for (var project in projects) {
      upgrades.add(await upgrade(project));
    }
    return upgrades;
  }

  Future<ProjectUpgrade> upgrade(DartProject project) async {
    var upgrades = await pubUpgrade(project);
    var outdated = await pubOutdated(project);
    var pods = await podUpdate(project);

    return ProjectUpgrade(project, upgrades,
        podUpdates: pods, outdated: outdated);
  }

  Future<List<PubUpgrade>> pubUpgrade(DartProject project) async {
    var process = ProcessRunner(
        defaultWorkingDirectory: project.directory, printOutputDefault: true);

    // Fail is ok because it could fail when there are no "example" folder (bug from pub I guess)
    await process.runProcess([dartOrFlutterBinary, 'pub', 'get'], failOk: true);
    var initialDependencies = LockDependency.loadDependencies(project.path);
    await process
        .runProcess([dartOrFlutterBinary, 'pub', 'upgrade'], failOk: true);
    var newDependencies = LockDependency.loadDependencies(project.path);

    var upgrades = <PubUpgrade>[];
    for (var newDependency in newDependencies) {
      var oldDependency = initialDependencies
          .firstWhereOrNull((p) => p.name == newDependency.name);

      if (oldDependency == null ||
          oldDependency.version != newDependency.version) {
        upgrades.add(PubUpgrade(project, oldDependency, newDependency));
      }
    }
    return upgrades;
  }

  Future<List<PubOutdated>> pubOutdated(DartProject project) async {
    var process = ProcessRunner(
        defaultWorkingDirectory: project.directory, printOutputDefault: true);

    // TODO(xha): use "dart pub outdated --json" when github/flutter use the correct
    // dart binary.
    var result = await process
        .runProcess([dartOrFlutterBinary, 'pub', 'outdated', '--', '--json']);
    var decoded = jsonDecode(result.stdout) as Map<String, Object?>;
    var packages = decoded['packages']! as List;

    String? version(Object? versionJson) {
      if (versionJson == null) return null;
      return (versionJson as Map<String, Object?>)['version']! as String;
    }

    var results = <PubOutdated>[];
    for (var package in packages) {
      var packageInfo = package as Map<String, Object?>;
      var outdated = PubOutdated.from(packageInfo['package']! as String,
          current: version(packageInfo['current']),
          resolvable: version(packageInfo['resolvable']),
          latest: version(packageInfo['latest'])!);
      if (outdated != null) {
        results.add(outdated);
      }
    }
    return results;
  }

  Future<List<PodUpdate>> podUpdate(DartProject project) async {
    var results = <PodUpdate>[];

    for (var dir in ['iOS', 'macOS']) {
      var iosDir = p.join(project.path, dir.toLowerCase());
      var process = ProcessRunner(
          defaultWorkingDirectory: Directory(iosDir), printOutputDefault: true);
      if (File(p.join(iosDir, 'Podfile')).existsSync()) {
        // Allows to fix some incompatibilities (https://stackoverflow.com/questions/48638059/could-not-find-compatible-versions-for-pod)
        File(p.join(iosDir, 'Podfile.lock')).deleteSync();

        await process.runProcess(['pod', 'install', '--repo-update']);
        await process.runProcess(['pod', 'update']);

        var result = await process.runProcess(
            ['git', 'diff', '--exit-code', 'Podfile.lock'],
            failOk: true);
        if (result.exitCode != 0) {
          results.add(PodUpdate(dir, result.stdout));
        }
      }
    }
    return results;
  }
}

class ProjectUpgrade {
  final DartProject project;
  late List<PubUpgrade> _pubUpgrades;
  final List<PodUpdate> podUpdates;
  final List<PubOutdated> outdated;

  ProjectUpgrade(this.project, List<PubUpgrade> upgrades,
      {List<PodUpdate>? podUpdates, List<PubOutdated>? outdated})
      : outdated = outdated ?? [],
        podUpdates = podUpdates ?? [] {
    _pubUpgrades = upgrades.toList();
    mergeSort<PubUpgrade>(_pubUpgrades, compare: (a, b) {
      return a.type.index.compareTo(b.type.index);
    });
  }

  List<PubUpgrade> get pubUpgrades => _pubUpgrades;

  bool get hasChanged =>
      _pubUpgrades.isNotEmpty || podUpdates.isNotEmpty || outdated.isNotEmpty;

  @override
  String toString() =>
      'ProjectUpgrade(${project.packageName}, upgrades: ${pubUpgrades.length})';
}

enum UpgradeType { breaking, major, minor, patch, newDep }

UpgradeType upgradeType(Version? from, Version to) {
  if (from == null) return UpgradeType.newDep;

  if (to >= from.nextBreaking) {
    return UpgradeType.breaking;
  } else if (to >= from.nextMajor) {
    return UpgradeType.major;
  } else if (to >= from.nextMinor) {
    return UpgradeType.minor;
  }
  return UpgradeType.patch;
}

class PubUpgrade {
  final DartProject project;
  final String package;
  final Version? from;
  final Version to;
  final bool isHosted;
  late UpgradeType _type;

  PubUpgrade(this.project, LockDependency? before, LockDependency after)
      : package = after.name,
        isHosted = after.isHosted,
        from = before != null ? Version.parse(before.version) : null,
        to = Version.parse(after.version) {
    _type = upgradeType(from, to);
  }

  UpgradeType get type => _type;

  bool get isBreaking => _type == UpgradeType.breaking;

  @override
  String toString() => 'PackageUpgrade($package, from: $from, to: $to)';
}

class PodUpdate {
  final String name;
  final String diff;

  PodUpdate(this.name, this.diff);
}

class PubOutdated {
  final String package;
  final Version? current;
  final Version latest;
  final Version? resolvable;

  PubOutdated(this.package,
      {required this.current, required this.resolvable, required this.latest});

  static PubOutdated? from(String name,
      {required String? current,
      required String? resolvable,
      required String latest}) {
    if (current == latest) return null;

    String? resolvableResult;
    String? latestResult;
    if (current != resolvable) {
      resolvableResult = resolvable;
      if (resolvable != latest) {
        latestResult = latest;
      }
    }
    latestResult ??= latest;
    return PubOutdated(name,
        current: current != null ? Version.parse(current) : null,
        resolvable:
            resolvableResult != null ? Version.parse(resolvableResult) : null,
        latest: Version.parse(latestResult));
  }
}

class LockDependency {
  final String name;
  final String source;
  final String version;

  LockDependency(this.name, {required this.source, required this.version});

  bool get isHosted => source == 'hosted';

  static List<LockDependency> loadDependencies(String packagePath) {
    var map =
        loadYaml(File(p.join(packagePath, 'pubspec.lock')).readAsStringSync())
            as YamlMap;
    var packages = map['packages'] as YamlMap;

    var results = <LockDependency>[];
    for (var package in packages.keys) {
      var packageInfo = packages[package] as YamlMap;
      results.add(LockDependency(
        package as String,
        source: packageInfo['source'] as String,
        version: packageInfo['version'] as String,
      ));
    }
    return results;
  }

  @override
  String toString() => 'LockDependency($name, version: $version)';
}
