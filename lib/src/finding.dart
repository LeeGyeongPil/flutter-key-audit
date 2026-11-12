/// Result model: what was found, where, how serious, and how to fix it.
library;

/// How serious a finding is. Declared from most to least serious.
enum Severity {
  /// A key that bills money or exposes data when stolen.
  billing,

  /// Needs a human decision (for example a Google key with no context).
  review,

  /// Public by design (for example a Firebase web key).
  info;

  /// Higher means more serious.
  int get rank => switch (this) {
    Severity.billing => 2,
    Severity.review => 1,
    Severity.info => 0,
  };
}

/// Where a finding sits. Binary inputs have a byte [offset], text inputs a
/// 1-based [line].
class Location {
  const Location(this.path, {this.offset, this.line});

  /// `<archive>!/<entry>` for archive entries, otherwise a file path.
  final String path;
  final int? offset;
  final int? line;

  /// Human readable form used by the table.
  String get text {
    if (offset != null) return '$path @0x${offset!.toRadixString(16)}';
    if (line != null) return '$path:$line';
    return path;
  }
}

/// One detected key. The raw value is kept only in memory ([raw]) so callers
/// can compare it in tests; no report writes it.
class Finding {
  Finding({
    required this.rule,
    required this.severity,
    required this.confidence,
    required String raw,
    required this.location,
    required this.fix,
    this.context = const [],
    this.recovered,
  }) : _raw = raw,
       redacted = redact(raw);

  final String rule;
  final Severity severity;

  /// `high` or `medium`.
  final String confidence;

  /// First 8 characters + `...` + last 4 characters.
  final String redacted;
  final Location location;

  /// Language-neutral fix code, see `fix_*` messages.
  final String fix;

  /// Evidence codes behind the severity (language-neutral).
  final List<String> context;

  /// `envied` when the key was rebuilt from XOR-obfuscated source arrays.
  final String? recovered;

  final String _raw;

  /// The raw key. For in-process comparison only; never print or serialize it.
  String get raw => _raw;

  @override
  String toString() =>
      'Finding($rule, ${severity.name}, $redacted, ${location.text})';
}

/// Shows the first 8 and last 4 characters; short values are fully hidden.
String redact(String value) => value.length <= 12
    ? '****'
    : '${value.substring(0, 8)}...${value.substring(value.length - 4)}';

/// Picks the fix code for a finding.
String fixFor({
  required String rule,
  required Severity severity,
  String? recovered,
  List<String> context = const [],
}) {
  if (recovered == 'envied') return 'envied_is_not_encryption';
  if (rule == 'google-api-key') {
    return switch (severity) {
      Severity.billing => 'gemini_backend_or_firebase_ai_logic',
      Severity.info => 'firebase_key_restrict',
      Severity.review => 'review_google_key',
    };
  }
  return 'rotate_and_proxy';
}
