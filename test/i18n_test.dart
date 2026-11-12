import 'dart:io';

import 'package:flutter_key_audit/src/errors.dart';
import 'package:flutter_key_audit/src/i18n.dart';
import 'package:flutter_key_audit/src/messages_en.dart';
import 'package:flutter_key_audit/src/messages_ko.dart';
import 'package:flutter_key_audit/src/rules.dart';
import 'package:test/test.dart';

import 'helpers/fixtures.dart';

void main() {
  group('language resolution', () {
    test('--lang beats everything', () {
      final env = {
        'FLUTTER_KEY_AUDIT_LANG': 'ko',
        'LC_ALL': 'ko_KR.UTF-8',
        'LANG': 'ko_KR.UTF-8',
      };
      expect(resolveLang('en', env), Lang.en);
      expect(resolveLang('ko', {'LANG': 'en_US.UTF-8'}), Lang.ko);
    });

    test('order: tool variable > LC_ALL > LC_MESSAGES > LANG', () {
      expect(
        resolveLang(null, {'FLUTTER_KEY_AUDIT_LANG': 'ko', 'LC_ALL': 'en_US'}),
        Lang.ko,
      );
      expect(
        resolveLang(null, {'FLUTTER_KEY_AUDIT_LANG': 'en', 'LC_ALL': 'ko_KR'}),
        Lang.en,
      );
      expect(
        resolveLang(null, {
          'LC_ALL': 'ko_KR.UTF-8',
          'LC_MESSAGES': 'en_US',
          'LANG': 'en_US',
        }),
        Lang.ko,
      );
      expect(
        resolveLang(null, {'LC_ALL': 'C', 'LANG': 'ko_KR.UTF-8'}),
        Lang.en,
      );
      expect(
        resolveLang(null, {'LC_MESSAGES': 'ko_KR.UTF-8', 'LANG': 'en_US'}),
        Lang.ko,
      );
      expect(resolveLang(null, {'LANG': 'ko_KR.UTF-8'}), Lang.ko);
    });

    test('empty values are skipped and non-ko means English', () {
      expect(resolveLang(null, {'LC_ALL': '', 'LANG': 'ko_KR'}), Lang.ko);
      expect(resolveLang(null, {'LANG': 'fr_FR.UTF-8'}), Lang.en);
      expect(resolveLang(null, {}), Lang.en);
    });

    test('an invalid --lang value is ignored by resolveLang', () {
      expect(resolveLang('fr', {'LANG': 'ko_KR'}), Lang.ko);
    });
  });

  group('catalogs', () {
    test('both languages have identical keys', () {
      expect(messagesKo.keys.toSet(), messagesEn.keys.toSet());
    });

    test('no empty text and the same placeholders in each key', () {
      final ph = RegExp(r'\{([a-zA-Z_]+)\}');
      for (final key in messagesEn.keys) {
        expect(messagesEn[key], isNotEmpty, reason: key);
        expect(messagesKo[key], isNotEmpty, reason: key);
        Set<String> names(String s) =>
            ph.allMatches(s).map((m) => m[1]!).toSet();
        expect(names(messagesKo[key]!), names(messagesEn[key]!), reason: key);
      }
    });

    test('Korean text has no fixed particle right after a placeholder', () {
      final bad = RegExp(
        r'''\{[a-zA-Z_]+\}["'”’)\]]*\s*(이|가|은|는|을|를|와|과|으로|로|의|에|에서|도|만)(?![가-힣])''',
      );
      for (final e in messagesKo.entries) {
        expect(bad.hasMatch(e.value), isFalse, reason: '${e.key}: ${e.value}');
      }
    });

    test('Korean strings are really Korean where they should be', () {
      expect(messagesKo['no_findings'], matches(RegExp('[가-힣]')));
      expect(messagesKo['path_not_found'], matches(RegExp('[가-힣]')));
    });

    test('every message key used in lib/src exists in the catalog', () {
      final used = <String>{};
      final call = RegExp(r"""\bt\(\s*\w+,\s*'([a-z_]+)'""");
      final paramCode = RegExp(r"""AuditException\(\s*'([a-z_]+)'""");
      for (final entity in Directory('lib/src').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        used.addAll(call.allMatches(text).map((m) => m[1]!));
        used.addAll(paramCode.allMatches(text).map((m) => m[1]!));
      }
      expect(used, isNotEmpty);
      for (final key in used) {
        expect(messagesEn, contains(key), reason: 'missing message: $key');
      }
      // Keys built from other values.
      for (final sev in ['billing', 'review', 'info']) {
        expect(messagesEn, contains('sev_$sev'));
      }
      for (final r in rules) {
        expect(messagesEn, contains('rule_${r.id}'));
      }
      for (final fix in [
        'rotate_and_proxy',
        'gemini_backend_or_firebase_ai_logic',
        'firebase_key_restrict',
        'review_google_key',
        'envied_is_not_encryption',
      ]) {
        expect(messagesEn, contains('fix_$fix'));
      }
      for (final c in ['scan', 'rules', 'demo']) {
        expect(messagesEn, contains('help_${c}_usage'));
      }
    });
  });

  group('the CLI switches language', () {
    test('help differs by --lang and not by the environment alone', () {
      final en = cli(['--help']);
      final ko = cli(['--help', '--lang', 'ko']);
      expect(en.out, contains('Usage: flutter-key-audit'));
      expect(ko.out, contains('사용법'));
      expect(ko.out, isNot(contains('Usage:')));
      // --lang after the command works too.
      expect(cli(['scan', '--help', '--lang', 'ko']).out, contains('사용법'));
      expect(cli(['--lang=ko', '--help']).out, contains('사용법'));
    });

    test('environment variables choose the language', () {
      expect(
        cli(['--help'], env: {'FLUTTER_KEY_AUDIT_LANG': 'ko'}).out,
        contains('사용법'),
      );
      expect(
        cli(['--help'], env: {'LANG': 'ko_KR.UTF-8'}).out,
        contains('사용법'),
      );
      expect(
        cli(['--help'], env: {'LC_ALL': 'C', 'LANG': 'ko_KR.UTF-8'}).out,
        contains('Usage:'),
      );
      expect(
        cli(['--help', '--lang', 'en'], env: {'LANG': 'ko_KR.UTF-8'}).out,
        contains('Usage:'),
      );
    });

    test('table output is localized', () {
      final dir = tempDir();
      final apk = buildApk('${dir.path}/a.apk');
      final en = cli(['scan', apk.file.path]);
      final ko = cli(['scan', apk.file.path, '--lang', 'ko']);
      expect(en.out, contains('SEVERITY'));
      expect(en.out, contains('3 billing'));
      expect(ko.out, contains('등급'));
      expect(ko.out, contains('과금 3건'));
      expect(ko.out, contains('처방'));
    });

    test('AuditException code and params are localized', () {
      final en = cli(['scan', '/definitely/not/here.apk']);
      final ko = cli(['scan', '/definitely/not/here.apk', '--lang', 'ko']);
      expect(en.err, contains('Path not found: /definitely/not/here.apk'));
      expect(ko.err, contains('경로를 찾을 수 없습니다: /definitely/not/here.apk'));
      expect(en.code, ko.code);
      expect(t(Lang.ko, const AuditException('no_paths').code), contains('경로'));
    });

    test('argument parse errors are localized', () {
      final en = cli(['scan', 'x', '--bogus']);
      final ko = cli(['scan', 'x', '--bogus', '--lang', 'ko']);
      expect(en.err, contains('Unknown option: --bogus'));
      expect(ko.err, contains('알 수 없는 옵션: --bogus'));
      expect(en.code, 2);
      expect(ko.code, 2);

      expect(
        cli(['scan', 'x', '--format', 'xml']).err,
        contains(
          'Value not allowed for option --format: xml. Allowed: table, json, sarif.',
        ),
      );
      expect(
        cli(['scan', 'x', '--format', 'xml', '--lang', 'ko']).err,
        contains('허용되지 않는 값입니다 - 옵션: --format, 값: xml'),
      );
      expect(
        cli(['scan', 'x', '--format']).err,
        contains('Option needs a value: --format'),
      );
      expect(
        cli(['--lang', 'ko', 'scan', 'x', '--format']).err,
        contains('값이 필요한 옵션입니다'),
      );
      expect(cli(['zzz', '--lang', 'ko']).err, contains('알 수 없는 명령: zzz'));
      expect(
        cli(['--lang', 'fr']).err,
        contains('Value not allowed for option --lang: fr'),
      );
      expect(
        cli(['scan', 'x', '--min-entropy', 'abc', '--lang', 'ko']).err,
        contains('필요한 값: 0 이상의 숫자'),
      );
      expect(cli(['scan', '--lang', 'ko']).err, contains('경로가 하나 이상 필요합니다'));
      expect(cli(['--lang', 'ko']).err, contains('명령이 없습니다'));
    });

    test('json output and exit codes are identical in both languages', () {
      final dir = tempDir();
      final apk = buildApk('${dir.path}/a.apk');
      final en = cli(['scan', apk.file.path, '--format', 'json']);
      final ko = cli([
        'scan',
        apk.file.path,
        '--format',
        'json',
        '--lang',
        'ko',
      ]);
      expect(ko.out, en.out);
      expect(ko.code, en.code);
      final sarEn = cli(['scan', apk.file.path, '--format', 'sarif']);
      final sarKo = cli([
        'scan',
        apk.file.path,
        '--format',
        'sarif',
        '--lang',
        'ko',
      ]);
      expect(sarKo.out, sarEn.out);
    });
  });
}
