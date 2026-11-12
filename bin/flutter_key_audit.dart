import 'dart:io';

import 'package:flutter_key_audit/src/cli.dart';

Future<void> main(List<String> args) async {
  final code = runCli(args);
  // Flush before exit so piped output is not cut off.
  await stdout.flush();
  await stderr.flush();
  exit(code);
}
