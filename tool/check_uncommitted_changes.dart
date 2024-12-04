import 'package:process_runner/process_runner.dart';

void main() async {
  var process = ProcessRunner(printOutputDefault: true);

  var result = await process.runProcess([
    'git',
    'diff',
    '--exit-code',
    '--stat',
    '--',
    '.',
  ]);
  if (result.exitCode != 0) {
    throw Exception(
      'Found changed files after build. please run dart tool/format.dart and commit the changes.',
    );
  }
}
