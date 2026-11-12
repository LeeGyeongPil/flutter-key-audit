/// Korean message catalog (formal polite style). Keys must match
/// `messages_en.dart` exactly. Do not put a fixed particle right after a
/// placeholder: write "파일: {path}" instead of "{path} 파일을".
const Map<String, String> messagesKo = {
  // Help
  'help_header':
      'flutter-key-audit {version} - Flutter 빌드 산출물에서 과금되는 AI 제공자 API 키를 찾습니다(오프라인).',
  'help_usage': '사용법: flutter-key-audit <명령> [옵션]',
  'help_commands': '명령:',
  'help_cmd_scan':
      'APK, AAB, IPA, zip, 빌드 폴더, 파일을 검사합니다. --source 를 주면 소스 폴더를 검사합니다.',
  'help_cmd_rules': '검출 규칙 목록을 보여 줍니다.',
  'help_cmd_demo': '연습용 목을 실행합니다. 무작위 가짜 키로 만든 합성 산출물을 검사합니다.',
  'help_global_options': '공통 옵션:',
  'help_scan_usage': '사용법: flutter-key-audit scan [옵션] <경로>...',
  'help_rules_usage': '사용법: flutter-key-audit rules [옵션]',
  'help_demo_usage': '사용법: flutter-key-audit demo [옵션]',
  'help_more': '명령별 옵션은 "flutter-key-audit <명령> --help" 로 확인하세요.',
  'help_exit_codes':
      '종료 코드: 0 은 --fail-on 기준 미만, 1 은 기준 이상 발견, 2 는 사용법 오류, 3 은 입력·실행 오류입니다.',
  'opt_lang': '출력 언어(기본: 환경 변수, 없으면 en).',
  'opt_help': '도움말을 보여 줍니다.',
  'opt_version': '버전을 출력합니다.',
  'opt_format': '보고서 형식.',
  'opt_output': '보고서를 표준 출력 대신 파일에 씁니다.',
  'opt_fail_on': '종료 코드를 1 로 만드는 가장 낮은 등급.',
  'opt_min_entropy': '이 섀넌 엔트로피(문자당 비트) 미만의 후보는 버립니다.',
  'opt_max_entry_mb': '이 크기(MB)보다 큰 파일과 압축 항목은 건너뜁니다.',
  'opt_exclude': '이 문자열이 들어간 경로는 건너뜁니다(반복 가능).',
  'opt_source': '소스 모드: 텍스트 파일을 읽고 envied 키를 복원하며 줄 번호를 보고합니다.',
  'opt_demo_out': '생성한 산출물을 둘 폴더(기본: 임시 폴더).',
  'opt_demo_aot': '가짜 키를 넣은 작은 Dart 프로그램도 컴파일합니다(PATH 에 dart 필요).',

  // Table
  'col_severity': '등급',
  'col_rule': '규칙',
  'col_value': '값',
  'col_location': '위치',
  'label_fix': '처방',
  'label_context': '근거',
  'label_confidence': '확신도',
  'label_recovered': '복원',
  'sev_billing': '과금',
  'sev_review': '확인 필요',
  'sev_info': '참고',
  'no_findings': 'AI 제공자 키를 찾지 못했습니다.',
  'summary':
      '검사한 파일 {files}개, 압축 항목 {entries}개: 과금 {billing}건, 확인 필요 {review}건, 참고 {info}건입니다.',
  'summary_skipped':
      '건너뜀: 너무 큰 항목 {entries}개, 엔트로피가 낮은 후보 {lowEntropy}개(--min-entropy 참고).',
  'summary_links':
      '건너뜀: 폴더를 가리키거나 대상이 없는 심볼릭 링크 {links}개 (실제 경로를 직접 넘기면 검사합니다).',
  'report_written': '보고서를 저장했습니다: {path}',
  'fix_guide_hint':
      '고치는 법: 키를 회전한 뒤 호출을 직접 만든 백엔드 뒤로 옮깁니다(docs/fix-guide.ko.md).',

  // Fix codes (one line each)
  'fix_rotate_and_proxy': '제공자 콘솔에서 이 키를 바로 회전하고, 앱 대신 백엔드에서 API 를 호출하세요.',
  'fix_gemini_backend_or_firebase_ai_logic':
      '이 Gemini 키를 회전하고, 백엔드 또는 App Check 를 쓴 Firebase AI Logic 으로 Gemini 를 호출하세요.',
  'fix_firebase_key_restrict':
      '공개 전제인 Firebase 키입니다. 앱으로 사용 제한을 걸고 허용 API 목록에서 Generative Language API 를 빼세요.',
  'fix_review_google_key':
      'Google Cloud 에서 이 키가 Generative Language API 를 호출할 수 있는지 확인하고, 가능하면 회전하세요.',
  'fix_envied_is_not_encryption': 'envied 난독화는 암호화가 아닙니다. 이 키를 회전하고 백엔드에 두세요.',

  // Rule descriptions
  'rule_anthropic': 'Anthropic API 키 (sk-ant-...)',
  'rule_openai-project': 'OpenAI 프로젝트·서비스 계정·관리자 키 (sk-proj-...)',
  'rule_openai-legacy': 'T3BlbkFJ 표지가 있는 OpenAI 키 (sk-...)',
  'rule_openrouter': 'OpenRouter API 키 (sk-or-v1-...)',
  'rule_groq': 'Groq API 키 (gsk_...)',
  'rule_huggingface': 'Hugging Face 액세스 토큰 (hf_...)',
  'rule_replicate': 'Replicate API 토큰 (r8_...)',
  'rule_xai': 'xAI API 키 (xai-...)',
  'rule_google-api-key':
      'Google API 키 (AIza...): Firebase 키는 공개 전제이고 Gemini 키는 아니므로 문맥으로 판정합니다',
  'rules_header': '검출 규칙 ({count}개):',

  // Errors
  'error_prefix': '오류',
  'path_not_found':
      '경로를 찾을 수 없습니다: {path}. 경로를 확인하거나 먼저 "flutter build" 를 실행하세요.',
  'corrupt_zip':
      '압축 파일을 읽을 수 없습니다: {path}. zip 형식이지만 손상되었거나 일부만 남았으니 다시 빌드하세요.',
  'no_paths':
      'scan 에는 경로가 하나 이상 필요합니다. 예: flutter-key-audit scan app-release.apk',
  'usage_no_command': '명령이 없습니다. scan, rules, demo 중 하나를 쓰세요(--help 참고).',
  'usage_unknown_command': '알 수 없는 명령: {name}. scan, rules, demo 중 하나를 쓰세요.',
  'usage_unknown_option': '알 수 없는 옵션: {name}. --help 를 확인하세요.',
  'usage_missing_value': '값이 필요한 옵션입니다: {name}.',
  'usage_not_allowed':
      '허용되지 않는 값입니다 - 옵션: {name}, 값: {value}, 허용 값: {allowed}.',
  'usage_cannot_negate': '부정할 수 없는 옵션입니다: {name}.',
  'usage_invalid': '인자가 올바르지 않습니다: {detail}',
  'usage_invalid_value':
      '값이 올바르지 않습니다 - 옵션: {name}, 값: {value}, 필요한 값: {expected}.',
  'expected_number': '0 이상의 숫자',
  'expected_positive_int': '1 이상의 정수',
  'dart_not_found':
      'dart 명령을 찾을 수 없습니다. Dart 또는 Flutter SDK 를 설치하고 PATH 에 dart 를 넣은 뒤 demo --aot 를 다시 실행하세요.',
  'aot_compile_failed': 'dart 컴파일에 실패했습니다. 자세한 내용: {detail}',
  'write_failed': '파일을 쓸 수 없습니다: {path}. 자세한 내용: {detail}',

  // Demo
  'demo_banner':
      '연습용 목(practice mock): 무작위로 만든 가짜 키가 들어 있는 합성 산출물입니다. 여기 있는 키는 모두 가짜입니다.',
  'demo_out': '산출물 위치: {path}',
  'demo_direct_title': 'direct 빌드: 앱이 AI API 를 직접 호출합니다',
  'demo_proxy_title': 'proxy 빌드: 앱은 백엔드를 호출하고 키는 백엔드가 가집니다',
  'demo_result_direct': 'direct: 과금 {billing}건, 참고 {info}건',
  'demo_result_proxy': 'proxy: 과금 {billing}건, 참고 {info}건',
  'demo_lesson':
      '교훈: 앱 안에 실린 키는 앱을 내려받은 누구나 읽을 수 있습니다. 숨기는 것이 아니라 구조를 고쳐서 키를 백엔드에 두세요(docs/fix-guide.ko.md).',
  'demo_next':
      '다음 단계: 내 빌드를 검사해 보세요. 예: flutter-key-audit scan build/app/outputs/flutter-apk/app-release.apk',
  'demo_aot_title':
      '연습용 목(practice mock): 가짜 키를 -D 로 넣고 실제 "dart compile aot-snapshot" 을 실행합니다',
  'demo_aot_plain': 'aot plain: {status}',
  'demo_aot_obfuscated': 'aot obfuscated: {status}',
  'demo_aot_detected': '검출됨 ({rule})',
  'demo_aot_not_detected': '검출 안 됨',
  'demo_aot_lesson':
      '교훈: --dart-define 도 --obfuscate 도 키를 숨기지 못합니다. 값은 바이너리 안의 컴파일 시점 상수입니다.',
};
