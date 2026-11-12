/// Offline scanner for AI provider API keys in Flutter build outputs.
///
/// The command line is the main interface. This library exports the few
/// pieces needed for tests and integrations. Its API may change between 0.x
/// releases.
library;

export 'src/errors.dart' show AuditException;
export 'src/finding.dart' show Finding, Location, Severity, redact;
export 'src/options.dart' show ScanOptions, ScanResult, ScanStats;
export 'src/rules.dart' show KeyRule, rules;
export 'src/walker.dart' show scanPaths;
