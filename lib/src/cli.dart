import 'dart:io';

import 'package:args/args.dart';

import 'demo.dart';
import 'errors.dart';
import 'finding.dart';
import 'i18n.dart';
import 'options.dart';
import 'report/json.dart';
import 'report/sarif.dart';
import 'report/table.dart';
import 'rules.dart';
import 'walker.dart';

const _formats = ['table', 'json', 'sarif'];
const _failLevels = ['billing', 'review', 'info', 'none'];

/// Allowed values shown in localized "value not allowed" errors.
const _allowedByOption = {
  '--format': _formats,
  '--fail-on': _failLevels,
  '--lang': ['en', 'ko'],
};

/// Runs the command line and returns the process exit code.
///
/// Exit codes: 0 below the `--fail-on` level, 1 at or above it, 2 usage
/// error, 3 input or runtime error. Output goes to [out] and [err]; tests pass
/// their own sinks and an [environment] map (so the real `LANG` is ignored).
/// [dartCommand] is the executable used by `demo --aot`.
int runCli(
  List<String> args, {
  Map<String, String>? environment,
  StringSink? out,
  StringSink? err,
  String dartCommand = 'dart',
}) {
  final env = environment ?? Platform.environment;
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;
  // The language must be known before parsing so parse errors can be localized.
  var lang = resolveLang(_langFromArgs(args), env);
  try {
    return _run(
      args,
      env,
      stdoutSink,
      stderrSink,
      dartCommand,
      (l) => lang = l,
    );
  } on ArgParserException catch (e) {
    final (code, params) = _mapParseError(e);
    stderrSink.writeln('${t(lang, 'error_prefix')}: ${t(lang, code, params)}');
    stderrSink.writeln(t(lang, 'help_more'));
    return 2;
  } on AuditException catch (e) {
    stderrSink.writeln(
      '${t(lang, 'error_prefix')}: ${t(lang, e.code, _localizedParams(lang, e))}',
    );
    return e.exitCode;
  }
}

/// Reads `--lang` out of the raw arguments (last valid value wins).
String? _langFromArgs(List<String> args) {
  String? found;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--lang' && i + 1 < args.length) {
      if (parseLang(args[i + 1]) != null) found = args[i + 1];
    } else if (a.startsWith('--lang=')) {
      final v = a.substring('--lang='.length);
      if (parseLang(v) != null) found = v;
    }
  }
  return found;
}

/// Some params are themselves message keys (for example `expected`).
Map<String, Object?> _localizedParams(Lang lang, AuditException e) {
  final p = Map<String, Object?>.from(e.params);
  final expected = p['expected'];
  if (expected is String) p['expected'] = t(lang, expected);
  return p;
}

(String, Map<String, Object?>) _mapParseError(ArgParserException e) {
  final message = e.message;
  final quoted = RegExp(
    r'"([^"]*)"',
  ).allMatches(message).map((m) => m.group(1)!).toList();
  String first() => quoted.isNotEmpty ? quoted.first : '';
  if (message.startsWith('Could not find an option')) {
    return ('usage_unknown_option', {'name': first()});
  }
  if (message.startsWith('Could not find a command')) {
    return ('usage_unknown_command', {'name': first()});
  }
  if (message.startsWith('Missing argument for')) {
    return ('usage_missing_value', {'name': first()});
  }
  if (message.contains('is not an allowed value for option')) {
    final name = e.argumentName ?? (quoted.length > 1 ? quoted[1] : '');
    return (
      'usage_not_allowed',
      {
        'name': name,
        'value': first(),
        'allowed': (_allowedByOption[name] ?? const <String>[]).join(', '),
      },
    );
  }
  if (message.startsWith('Cannot negate')) {
    return ('usage_cannot_negate', {'name': e.argumentName ?? first()});
  }
  return ('usage_invalid', {'detail': message});
}

ArgParser _commandParser(Lang lang, String command) {
  final p = ArgParser(usageLineLength: 100)
    ..addFlag('help', abbr: 'h', negatable: false, help: t(lang, 'opt_help'))
    ..addOption('lang', allowed: ['en', 'ko'], help: t(lang, 'opt_lang'));
  switch (command) {
    case 'scan':
      p
        ..addOption(
          'format',
          abbr: 'f',
          allowed: _formats,
          defaultsTo: 'table',
          help: t(lang, 'opt_format'),
        )
        ..addOption('output', abbr: 'o', help: t(lang, 'opt_output'))
        ..addOption(
          'fail-on',
          allowed: _failLevels,
          defaultsTo: 'billing',
          help: t(lang, 'opt_fail_on'),
        )
        ..addOption(
          'min-entropy',
          defaultsTo: '3.0',
          help: t(lang, 'opt_min_entropy'),
        )
        ..addOption(
          'max-entry-mb',
          defaultsTo: '512',
          help: t(lang, 'opt_max_entry_mb'),
        )
        ..addMultiOption('exclude', help: t(lang, 'opt_exclude'))
        ..addFlag('source', negatable: false, help: t(lang, 'opt_source'));
    case 'demo':
      p
        ..addOption('out', help: t(lang, 'opt_demo_out'))
        ..addFlag('aot', negatable: false, help: t(lang, 'opt_demo_aot'));
  }
  return p;
}

ArgParser _rootParser(Lang lang) {
  final p = ArgParser(usageLineLength: 100)
    ..addFlag('help', abbr: 'h', negatable: false, help: t(lang, 'opt_help'))
    ..addFlag('version', negatable: false, help: t(lang, 'opt_version'))
    ..addOption('lang', allowed: ['en', 'ko'], help: t(lang, 'opt_lang'));
  for (final c in ['scan', 'rules', 'demo']) {
    p.addCommand(c, _commandParser(lang, c));
  }
  return p;
}

String _rootHelp(Lang lang) => [
  t(lang, 'help_header', {'version': toolVersion}),
  '',
  t(lang, 'help_usage'),
  '',
  t(lang, 'help_commands'),
  '  scan    ${t(lang, 'help_cmd_scan')}',
  '  rules   ${t(lang, 'help_cmd_rules')}',
  '  demo    ${t(lang, 'help_cmd_demo')}',
  '',
  t(lang, 'help_global_options'),
  _rootParser(lang).usage,
  '',
  t(lang, 'help_more'),
  t(lang, 'help_exit_codes'),
  '',
].join('\n');

String _commandHelp(Lang lang, String command) => [
  t(lang, 'help_${command}_usage'),
  '',
  _commandParser(lang, command).usage,
  '',
  t(lang, 'help_exit_codes'),
  '',
].join('\n');

int _run(
  List<String> args,
  Map<String, String> env,
  StringSink out,
  StringSink err,
  String dartCommand,
  void Function(Lang) setLang,
) {
  // Parse with English help text first; the language only affects messages,
  // and the real language is applied right after parsing.
  var lang = resolveLang(_langFromArgs(args), env);
  final results = _rootParser(lang).parse(args);
  final command = results.command;
  lang = resolveLang(
    (command?['lang'] as String?) ?? results['lang'] as String?,
    env,
  );
  setLang(lang);

  if (results['version'] as bool) {
    out.writeln('flutter-key-audit $toolVersion');
    return 0;
  }
  if (command == null) {
    if (results['help'] as bool) {
      out.write(_rootHelp(lang));
      return 0;
    }
    if (results.rest.isNotEmpty) {
      throw AuditException('usage_unknown_command', {
        'name': results.rest.first,
      }, 2);
    }
    throw const AuditException('usage_no_command', {}, 2);
  }
  if (command['help'] as bool || results['help'] as bool) {
    out.write(
      command.name == null
          ? _rootHelp(lang)
          : _commandHelp(lang, command.name!),
    );
    return 0;
  }
  return switch (command.name) {
    'scan' => _scan(command, lang, out, err),
    'rules' => _rules(lang, out),
    'demo' => _demo(command, lang, out, dartCommand),
    _ => throw const AuditException('usage_no_command', {}, 2),
  };
}

int _scan(ArgResults a, Lang lang, StringSink out, StringSink err) {
  if (a.rest.isEmpty) throw const AuditException('no_paths', {}, 2);
  final minEntropy = double.tryParse(a['min-entropy'] as String);
  if (minEntropy == null || minEntropy < 0) {
    throw AuditException('usage_invalid_value', {
      'name': '--min-entropy',
      'value': a['min-entropy'],
      'expected': 'expected_number',
    }, 2);
  }
  final maxMb = int.tryParse(a['max-entry-mb'] as String);
  if (maxMb == null || maxMb < 1) {
    throw AuditException('usage_invalid_value', {
      'name': '--max-entry-mb',
      'value': a['max-entry-mb'],
      'expected': 'expected_positive_int',
    }, 2);
  }
  final result = scanPaths(
    a.rest,
    options: ScanOptions(
      minEntropy: minEntropy,
      maxEntryBytes: maxMb * 1024 * 1024,
      excludes: a['exclude'] as List<String>,
      source: a['source'] as bool,
    ),
  );
  final report = switch (a['format']) {
    'json' => renderJson(result),
    'sarif' => renderSarif(result),
    _ => renderTable(result, lang),
  };
  final output = a['output'] as String?;
  if (output == null) {
    out.write(report);
  } else {
    try {
      File(output).writeAsStringSync(report);
    } on FileSystemException catch (e) {
      throw AuditException('write_failed', {
        'path': output,
        'detail': e.osError?.message ?? e.message,
      });
    }
    err.writeln(t(lang, 'report_written', {'path': output}));
  }
  return _exitFor(result, a['fail-on'] as String);
}

int _exitFor(ScanResult result, String failOn) {
  final threshold = switch (failOn) {
    'billing' => Severity.billing.rank,
    'review' => Severity.review.rank,
    'info' => Severity.info.rank,
    _ => 99, // none
  };
  return result.findings.any((f) => f.severity.rank >= threshold) ? 1 : 0;
}

int _rules(Lang lang, StringSink out) {
  out.writeln(t(lang, 'rules_header', {'count': rules.length}));
  final width = rules.map((r) => r.id.length).reduce((a, b) => a > b ? a : b);
  for (final r in rules) {
    out.writeln(
      '  ${r.id.padRight(width)}  ${t(lang, 'sev_${r.severity.name}')}'
      '  ${t(lang, 'rule_${r.id}')}',
    );
  }
  return 0;
}

int _demo(ArgResults a, Lang lang, StringSink out, String dartCommand) {
  final given = a['out'] as String?;
  final outDir =
      given ??
      Directory.systemTemp.createTempSync('flutter-key-audit-demo-').path;
  if (a['aot'] as bool) {
    final r = runAotDemo(outDir, dartCommand: dartCommand);
    printAotDemo(r, lang, out);
    return r.plain.detected && r.obfuscated.detected ? 0 : 1;
  }
  printArtifactDemo(runArtifactDemo(outDir), lang, out);
  return 0;
}
