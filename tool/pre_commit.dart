import 'package:project_tools/format_pre_commit.dart';

void main() async {
  var modifiedFiles = await formatModifiedGitFiles();
  print('tool/pre_commit git hook modified ${modifiedFiles.length}'
      ' file(s) before commit');
}
