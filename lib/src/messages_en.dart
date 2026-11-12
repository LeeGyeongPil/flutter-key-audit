/// English message catalog. Keys must match `messages_ko.dart` exactly.
const Map<String, String> messagesEn = {
  // Help
  'help_header':
      'flutter-key-audit {version} - find billable AI provider API keys in Flutter build output (offline).',
  'help_usage': 'Usage: flutter-key-audit <command> [options]',
  'help_commands': 'Commands:',
  'help_cmd_scan':
      'Scan an APK, AAB, IPA, zip, build folder, file or (with --source) a source tree.',
  'help_cmd_rules': 'List the detection rules.',
  'help_cmd_demo':
      'Run a practice mock: synthetic artifacts with random fake keys.',
  'help_global_options': 'Global options:',
  'help_scan_usage': 'Usage: flutter-key-audit scan [options] <path>...',
  'help_rules_usage': 'Usage: flutter-key-audit rules [options]',
  'help_demo_usage': 'Usage: flutter-key-audit demo [options]',
  'help_more': 'Run "flutter-key-audit <command> --help" for command options.',
  'help_exit_codes':
      'Exit codes: 0 below the --fail-on level, 1 at or above it, 2 usage error, 3 input or runtime error.',
  'opt_lang': 'Output language (default: from environment, else en).',
  'opt_help': 'Show help.',
  'opt_version': 'Print the version.',
  'opt_format': 'Report format.',
  'opt_output': 'Write the report to a file instead of stdout.',
  'opt_fail_on': 'Lowest severity that makes the exit code 1.',
  'opt_min_entropy':
      'Drop candidates below this Shannon entropy (bits per character).',
  'opt_max_entry_mb': 'Skip files and archive entries larger than this (MB).',
  'opt_exclude': 'Skip paths containing this text (repeatable).',
  'opt_source':
      'Source mode: read text files, recover envied keys, report line numbers.',
  'opt_demo_out':
      'Folder for the generated artifacts (default: a temp folder).',
  'opt_demo_aot':
      'Also compile a small Dart program with a fake key (needs dart on PATH).',

  // Table
  'col_severity': 'SEVERITY',
  'col_rule': 'RULE',
  'col_value': 'VALUE',
  'col_location': 'LOCATION',
  'label_fix': 'fix',
  'label_context': 'context',
  'label_confidence': 'confidence',
  'label_recovered': 'recovered',
  'sev_billing': 'billing',
  'sev_review': 'review',
  'sev_info': 'info',
  'no_findings': 'No AI provider keys found.',
  'summary':
      'Scanned {files} files and {entries} archive entries: {billing} billing, {review} review, {info} info.',
  'summary_skipped':
      'Skipped: {entries} oversized entries, {lowEntropy} low-entropy candidates (see --min-entropy).',
  'summary_links':
      'Skipped: {links} symlinks to folders or missing targets (pass the real path to scan them).',
  'report_written': 'Report written to: {path}',
  'fix_guide_hint':
      'How to fix: rotate the key, then move the call behind your own backend (docs/fix-guide.md).',

  // Fix codes (one line each)
  'fix_rotate_and_proxy':
      'Rotate this key at the provider now, then call the API from your backend instead of the app.',
  'fix_gemini_backend_or_firebase_ai_logic':
      'Rotate this Gemini key; call Gemini from a backend or through Firebase AI Logic with App Check.',
  'fix_firebase_key_restrict':
      'Public Firebase key: restrict it to your app and remove the Generative Language API from its allow list.',
  'fix_review_google_key':
      'Check in Google Cloud whether this key can call the Generative Language API; if so, rotate it.',
  'fix_envied_is_not_encryption':
      'envied obfuscation is not encryption: rotate this key and keep it on a backend.',

  // Rule descriptions
  'rule_anthropic': 'Anthropic API key (sk-ant-...)',
  'rule_openai-project':
      'OpenAI project, service account or admin key (sk-proj-...)',
  'rule_openai-legacy': 'OpenAI key with the T3BlbkFJ marker (sk-...)',
  'rule_openrouter': 'OpenRouter API key (sk-or-v1-...)',
  'rule_groq': 'Groq API key (gsk_...)',
  'rule_huggingface': 'Hugging Face access token (hf_...)',
  'rule_replicate': 'Replicate API token (r8_...)',
  'rule_xai': 'xAI API key (xai-...)',
  'rule_google-api-key':
      'Google API key (AIza...): Firebase keys are public, Gemini keys are not; context decides',
  'rules_header': 'Detection rules ({count}):',

  // Errors
  'error_prefix': 'error',
  'path_not_found':
      'Path not found: {path}. Check the path, or run "flutter build" first.',
  'corrupt_zip':
      'Cannot read archive: {path}. The file looks like a zip but is damaged or truncated; rebuild it.',
  'no_paths':
      'scan needs at least one path, for example: flutter-key-audit scan app-release.apk',
  'usage_no_command': 'No command given. Use scan, rules or demo (see --help).',
  'usage_unknown_command': 'Unknown command: {name}. Use scan, rules or demo.',
  'usage_unknown_option': 'Unknown option: {name}. See --help.',
  'usage_missing_value': 'Option needs a value: {name}.',
  'usage_not_allowed':
      'Value not allowed for option {name}: {value}. Allowed: {allowed}.',
  'usage_cannot_negate': 'Option cannot be negated: {name}.',
  'usage_invalid': 'Invalid arguments: {detail}',
  'usage_invalid_value':
      'Invalid value for option {name}: {value}. Expected {expected}.',
  'expected_number': 'a number of 0 or more',
  'expected_positive_int': 'a whole number of 1 or more',
  'dart_not_found':
      'The dart command was not found. Install the Dart or Flutter SDK and put dart on PATH, then run demo --aot again.',
  'aot_compile_failed': 'dart compile failed. Details: {detail}',
  'write_failed': 'Cannot write file: {path}. Details: {detail}',

  // Demo
  'demo_banner':
      'practice mock: synthetic artifacts with randomly generated fake keys. Nothing here is a real key.',
  'demo_out': 'Artifacts written to: {path}',
  'demo_direct_title': 'direct build: the app calls the AI API itself',
  'demo_proxy_title':
      'proxy build: the app calls your backend, the backend holds the key',
  'demo_result_direct': 'direct: {billing} billing, {info} info',
  'demo_result_proxy': 'proxy: {billing} billing, {info} info',
  'demo_lesson':
      'Lesson: a key that ships inside the app can be read by anyone who downloads it. The fix is structure, not hiding: keep the key on a backend (docs/fix-guide.md).',
  'demo_next':
      'Next: scan your own build, for example: flutter-key-audit scan build/app/outputs/flutter-apk/app-release.apk',
  'demo_aot_title':
      'practice mock: real "dart compile aot-snapshot" with a fake key in -D',
  'demo_aot_plain': 'aot plain: {status}',
  'demo_aot_obfuscated': 'aot obfuscated: {status}',
  'demo_aot_detected': 'detected ({rule})',
  'demo_aot_not_detected': 'not detected',
  'demo_aot_lesson':
      'Lesson: --dart-define and --obfuscate do not hide a key. The value is a compile-time constant inside the binary.',
};
