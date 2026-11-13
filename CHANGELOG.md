# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.1] - 2026-11-14

### Fixed
- Development checks (`dart analyze`, `dart format`) no longer pick up demo
  output folders (`fka-demo`, `fka-aot`, `build`); the format command is now
  limited to `lib bin test tool`.

## [0.1.0] - 2026-11-13

### Added
- `scan` command for APK, AAB, IPA and zip files (detected by magic bytes, not
  by extension), build folders, single files and, with `--source`, source trees.
- Printable-string extraction for AOT binaries (`libapp.so`, `App.framework/App`)
  and `main.dart.js`, with byte offsets.
- 9 AI provider rules: anthropic, openai-project, openai-legacy, openrouter, groq,
  huggingface, replicate, xai, google-api-key. Shannon entropy filter
  (`--min-entropy`) and leading key boundary.
- Google `AIza` key context classifier: Gemini endpoint in the same file is
  `billing`, Firebase markers are `info`, otherwise `review`.
- Source mode: envied XOR array recovery, `.env` and Dart literal line numbers,
  default exclusion of `build/`, `.dart_tool/`, `.git/`, `ios/Pods/`,
  `node_modules/`.
- Table, JSON and SARIF 2.1.0 reports. Keys are always redacted.
- `--fail-on billing|review|info|none` and documented exit codes 0, 1, 2, 3.
- English and Korean output (`--lang`, `FLUTTER_KEY_AUDIT_LANG`, `LC_ALL`,
  `LC_MESSAGES`, `LANG`).
- `rules` command and `demo` command (`demo --aot` compiles a real AOT snapshot).
- Fix guides in English and Korean, `tool/compare_scanners.sh`.

[Unreleased]: https://github.com/LeeGyeongPil/flutter-key-audit/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/LeeGyeongPil/flutter-key-audit/releases/tag/v0.1.1
[0.1.0]: https://github.com/LeeGyeongPil/flutter-key-audit/releases/tag/v0.1.0
