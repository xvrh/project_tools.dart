import 'package:project_tools/project_tools.dart';

void main() async {
  var modifiedFiles = await formatModifiedGitFiles();
  print('tool/pre_commit git hook modified ${modifiedFiles.length}'
      ' file(s) before commit');
}
