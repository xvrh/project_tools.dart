import 'package:project_tools/project_tools.dart';

void main() async {
  var formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );
  var modifiedFiles = await formatModifiedGitFiles(
    formatFile: (file) => formatFile(file, formatter),
  );
  print(
    'tool/pre_commit git hook modified ${modifiedFiles.length}'
    ' file(s) before commit',
  );
}
