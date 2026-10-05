import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/api/api_client.dart';
import 'data/app_state.dart';
import 'data/repositories/supabase_auth_repository.dart';
import 'data/repositories/supabase_form_repository.dart';
import 'pages/login_page.dart';
import 'pages/shell.dart';
import 'pages/splash_page.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

/// Supabase URL and key: from --dart-define(-from-file) when given, otherwise
/// from the bundled config/supabase.json, so a plain `flutter run` works too.
/// The publishable key (sb_publishable_…) or the legacy anon key both work.
Future<(String, String)> _loadSupabaseConfig() async {
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isNotEmpty && key.isNotEmpty) return (url, key);
  try {
    final json =
        jsonDecode(await rootBundle.loadString('config/supabase.json')) as Map;
    return (
      json['SUPABASE_URL'] as String? ?? '',
      json['SUPABASE_PUBLISHABLE_KEY'] as String? ?? '',
    );
  } catch (e) {
    debugPrint('No config/supabase.json: $e');
    return ('', '');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (supabaseUrl, supabaseKey) = await _loadSupabaseConfig();
  // Also catches the untouched placeholders from supabase.example.json.
  if (supabaseUrl.isEmpty ||
      supabaseKey.isEmpty ||
      supabaseUrl.contains('your-project-ref') ||
      supabaseKey.contains('...')) {
    runApp(const _MissingConfigApp());
    return;
  }
  final api = SupabaseApi(url: supabaseUrl, key: supabaseKey);
  final state = AppState(
    auth: SupabaseAuthRepository(api),
    forms: SupabaseFormRepository(api.dio),
  );
  // Not awaited: the app draws right away and shows the backdrop until the
  // saved session (if any) is restored.
  state.restoreSession();
  runApp(MyApp(state: state));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Formfield 表單中心',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  // Lives as long as the app process, so the intro (the login one, or the
  // splash when a session was restored) only plays on a cold start — not
  // after logging out or returning from the background.
  bool _playIntro = true;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (app) {
        // The intro's first frame, so its waves rise from here.
        AppState(isRestoring: true) => const BrandBackdrop(
          key: ValueKey('restoring'),
          waves: 0,
          decor: 0,
        ),
        AppState(isLoggedIn: true) when _playIntro => SplashPage(
          key: const ValueKey('splash'),
          onDone: () => setState(() => _playIntro = false),
        ),
        AppState(isLoggedIn: true) => const AppShell(key: ValueKey('shell')),
        _ => LoginPage(
          key: const ValueKey('login'),
          playIntro: _playIntro,
          onIntroDone: () => _playIntro = false,
        ),
      },
    );
  }
}

/// Shown instead of the app when it was started without the Supabase
/// settings, so the problem is visible on screen, not just in the console.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_outlined, size: 40),
                SizedBox(height: 16),
                Text(
                  '缺少 Supabase 設定',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                SelectableText(
                  '1. 複製 config/supabase.example.json 為 config/supabase.json\n'
                  '2. 填入 SUPABASE_URL 與 SUPABASE_PUBLISHABLE_KEY\n'
                  '3. 完全停止 App 後重新執行（Hot reload 不會重新打包設定檔）',
                  style: TextStyle(fontSize: 13, height: 1.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
