import 'package:flutter_key_audit/flutter_key_audit.dart';
import 'package:flutter_key_audit/src/fake_keys.dart';
import 'package:flutter_key_audit/src/rules.dart';
import 'package:test/test.dart';

void main() {
  final fake = FakeKeys();
  const ids = [
    'anthropic',
    'openai-project',
    'openai-legacy',
    'openrouter',
    'groq',
    'huggingface',
    'replicate',
    'xai',
    'google-api-key',
  ];

  test('there are exactly 9 rules', () {
    expect(rules.map((r) => r.id), ids);
  });

  group('detection', () {
    for (final id in ids) {
      test('$id detects a generated key and no other rule fires', () {
        final key = fake.forRule(id);
        final hits = matchRules('value = "$key";');
        expect(hits.map((h) => h.rule.id), [id]);
        expect(hits.single.text, key);
      });
    }
  });

  group('rejections', () {
    test('low entropy placeholder is dropped and counted', () {
      var skipped = 0;
      final hits = matchRules(
        'sk-proj-${'x' * 60}',
        onLowEntropy: () => skipped++,
      );
      expect(hits, isEmpty);
      expect(skipped, 1);
    });

    test('--min-entropy 0 keeps the placeholder', () {
      expect(matchRules('sk-proj-${'x' * 60}', minEntropy: 0), hasLength(1));
    });

    test('too short keys are not detected', () {
      final short = fake.forRule('anthropic').substring(0, 60);
      expect(matchRules(short), isEmpty);
      final shortGroq = fake.forRule('groq').substring(0, 40);
      expect(matchRules(shortGroq), isEmpty);
    });

    test('a key that is the tail of a longer identifier is not detected', () {
      for (final id in ids) {
        final key = fake.forRule(id);
        expect(matchRules('X$key'), isEmpty, reason: id);
        expect(matchRules('-$key'), isEmpty, reason: '$id after dash');
        expect(matchRules('a_$key'), isEmpty, reason: '$id after underscore');
      }
    });

    test('trailing boundary is only enforced when asked for', () {
      final key = fake.forRule('groq');
      expect(matchRules('${key}zz'), hasLength(1));
      expect(matchRules('${key}zz', trailingBoundary: true), isEmpty);
      expect(matchRules('$key"', trailingBoundary: true), hasLength(1));
    });
  });

  group('confidence', () {
    test('sk-proj key with the T3BlbkFJ marker is high', () {
      final key = fake.forRule('openai-project');
      expect(key, contains('T3BlbkFJ'));
      final rule = ruleById('openai-project')!;
      expect(confidenceFor(rule, key), 'high');
    });

    test('sk-proj key without the marker is medium', () {
      final key = fake.forRule('openai-project', marker: false);
      expect(key, isNot(contains('T3BlbkFJ')));
      final hit = matchRules(key).single;
      expect(confidenceFor(hit.rule, hit.text), 'medium');
    });
  });

  test('redaction keeps first 8 and last 4 characters', () {
    final key = fake.forRule('groq');
    expect(
      redact(key),
      '${key.substring(0, 8)}...${key.substring(key.length - 4)}',
    );
    expect(redact('short'), '****');
  });

  test('entropy: constant string is 0, random key is high', () {
    expect(shannonEntropy('aaaa'), 0);
    expect(shannonEntropy(fake.forRule('groq')), greaterThan(3.5));
  });
}
