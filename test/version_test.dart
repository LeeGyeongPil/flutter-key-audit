import 'dart:io';

import 'package:flutter_key_audit/src/report/json.dart';
import 'package:test/test.dart';

void main() {
  test('toolVersion matches the pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(toolVersion, match!.group(1));
  });
}
