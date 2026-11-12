import 'dart:math' as math;

import 'finding.dart';

/// One provider key format.
class KeyRule {
  KeyRule(this.id, this.severity, String pattern)
    // The leading boundary is always required: a key must not be the tail
    // of a longer identifier. The trailing boundary is applied separately
    // (see [matchRules]) because binaries have arbitrary neighbouring bytes.
    : regex = RegExp('(?<![A-Za-z0-9_\\-])(?:$pattern)');

  final String id;

  /// Default severity. `google-api-key` is refined by context.
  final Severity severity;
  final RegExp regex;
}

/// The marker OpenAI embeds in project and legacy keys.
const openAiMarker = 'T3BlbkFJ';

/// The 9 built-in rules. Formats checked 2026-11-13 against the providers'
/// public key prefixes and the gitleaks default rule set
/// (https://github.com/gitleaks/gitleaks/blob/master/config/gitleaks.toml).
final List<KeyRule> rules = List.unmodifiable([
  KeyRule(
    'anthropic',
    Severity.billing,
    r'sk-ant-(?:api|admin)\d{2}-[A-Za-z0-9_\-]{80,}',
  ),
  KeyRule(
    'openai-project',
    Severity.billing,
    r'sk-(?:proj|svcacct|admin)-[A-Za-z0-9_\-]{40,}',
  ),
  KeyRule(
    'openai-legacy',
    Severity.billing,
    r'sk-[A-Za-z0-9]{20}T3BlbkFJ[A-Za-z0-9]{20}',
  ),
  KeyRule('openrouter', Severity.billing, r'sk-or-v1-[a-f0-9]{64}'),
  KeyRule('groq', Severity.billing, r'gsk_[A-Za-z0-9]{52}'),
  KeyRule('huggingface', Severity.billing, r'hf_[A-Za-z0-9]{34}'),
  KeyRule('replicate', Severity.billing, r'r8_[A-Za-z0-9]{37}'),
  KeyRule('xai', Severity.billing, r'xai-[A-Za-z0-9]{80}'),
  // Public by design for Firebase, billable for Gemini: context decides.
  KeyRule('google-api-key', Severity.review, r'AIza[0-9A-Za-z_\-]{35}'),
]);

/// Looks up a rule by id, or returns null.
KeyRule? ruleById(String id) {
  for (final r in rules) {
    if (r.id == id) return r;
  }
  return null;
}

/// Shannon entropy in bits per character.
double shannonEntropy(String s) {
  if (s.isEmpty) return 0;
  final counts = <int, int>{};
  for (final c in s.codeUnits) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  var h = 0.0;
  for (final n in counts.values) {
    final p = n / s.length;
    h -= p * (math.log(p) / math.ln2);
  }
  return h;
}

/// A rule hit inside a piece of text.
class RuleMatch {
  const RuleMatch(this.rule, this.start, this.text);
  final KeyRule rule;
  final int start;
  final String text;
}

final RegExp _identChar = RegExp(r'[A-Za-z0-9_\-]');

/// Finds all rule hits in [text].
///
/// Candidates whose Shannon entropy is below [minEntropy] are dropped and
/// reported through [onLowEntropy] (placeholders such as `xxxx...`).
/// With [trailingBoundary] a hit followed by another key character is
/// rejected; use it for text sources, not for binaries.
List<RuleMatch> matchRules(
  String text, {
  double minEntropy = 3.0,
  bool trailingBoundary = false,
  void Function()? onLowEntropy,
}) {
  final hits = <RuleMatch>[];
  for (final rule in rules) {
    for (final m in rule.regex.allMatches(text)) {
      final value = m.group(0)!;
      if (trailingBoundary &&
          m.end < text.length &&
          _identChar.hasMatch(text[m.end])) {
        continue;
      }
      if (shannonEntropy(value) < minEntropy) {
        onLowEntropy?.call();
        continue;
      }
      hits.add(RuleMatch(rule, m.start, value));
    }
  }
  return hits;
}

/// `high` for formats that are unmistakable, `medium` for an OpenAI project
/// key without the `T3BlbkFJ` marker (the format may change).
String confidenceFor(KeyRule rule, String value) {
  if (rule.id == 'openai-project' && !value.contains(openAiMarker)) {
    return 'medium';
  }
  return 'high';
}
