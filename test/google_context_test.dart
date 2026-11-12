import 'package:flutter_key_audit/flutter_key_audit.dart';
import 'package:flutter_key_audit/src/fake_keys.dart';
import 'package:test/test.dart';

import 'helpers/fixtures.dart';

void main() {
  final fake = FakeKeys();

  test('Gemini endpoint in the same entry -> billing', () {
    final dir = tempDir();
    final key = fake.forRule('google-api-key');
    writeBytes(
      '${dir.path}/libapp.so',
      binaryWith([
        'https://generativelanguage.googleapis.com/v1beta/models',
        'apiKey: "$key"',
      ]),
    );
    final f = scanPaths([dir.path]).findings.single;
    expect(f.rule, 'google-api-key');
    expect(f.severity, Severity.billing);
    expect(f.context, ['gemini_endpoint']);
    expect(f.fix, 'gemini_backend_or_firebase_ai_logic');
  });

  test('Firebase markers next to the key -> info', () {
    final dir = tempDir();
    final key = fake.forRule('google-api-key');
    writeBytes(
      '${dir.path}/libapp.so',
      binaryWith([
        'authDomain: "demo.firebaseapp.com", projectId: "demo"',
        'apiKey: "$key"',
      ]),
    );
    final f = scanPaths([dir.path]).findings.single;
    expect(f.severity, Severity.info);
    expect(
      f.context,
      containsAll([
        'firebase_marker:authDomain',
        'firebase_marker:projectId',
        'firebase_marker:firebaseapp.com',
      ]),
    );
    expect(f.fix, 'firebase_key_restrict');
  });

  test('google-services.json by file name -> info', () {
    final dir = tempDir();
    final key = fake.forRule('google-api-key');
    writeText('${dir.path}/google-services.json', '{"current_key": "$key"}\n');
    final f = scanPaths([dir.path]).findings.single;
    expect(f.severity, Severity.info);
    expect(f.context, ['firebase_file:google-services.json']);
  });

  test('no context at all -> review', () {
    final dir = tempDir();
    final key = fake.forRule('google-api-key');
    writeBytes('${dir.path}/libapp.so', binaryWith(['k=$key']));
    final f = scanPaths([dir.path]).findings.single;
    expect(f.severity, Severity.review);
    expect(f.context, ['no_context']);
    expect(f.fix, 'review_google_key');
  });

  test('Gemini endpoint wins over Firebase markers, evidence lists both', () {
    final dir = tempDir();
    final key = fake.forRule('google-api-key');
    writeBytes(
      '${dir.path}/libapp.so',
      binaryWith(['projectId', geminiHostForTest, 'k=$key']),
    );
    final f = scanPaths([dir.path]).findings.single;
    expect(f.severity, Severity.billing);
    expect(
      f.context,
      containsAll(['gemini_endpoint', 'firebase_marker:projectId']),
    );
  });

  test('the context is per entry, not per archive', () {
    final dir = tempDir();
    final key = fake.forRule('google-api-key');
    final zip = buildZip({
      'a.so': binaryWith([geminiHostForTest]),
      'b.so': binaryWith(['k=$key']),
    });
    writeBytes('${dir.path}/x.apk', zip);
    final f = scanPaths(['${dir.path}/x.apk']).findings.single;
    expect(f.severity, Severity.review);
  });
}

const geminiHostForTest = 'https://generativelanguage.googleapis.com/';
