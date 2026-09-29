import 'package:flutter/material.dart';

import 'data/app_state.dart';
import 'pages/login_page.dart';
import 'pages/shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(MyApp(state: AppState()));
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
  // Lives as long as the app process, so the login intro only plays on a
  // cold start — not after logging out or returning from the background.
  bool _playIntro = true;

  @override
  Widget build(BuildContext context) {
    final loggedIn = AppScope.of(context).isLoggedIn;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: loggedIn
          ? const AppShell(key: ValueKey('shell'))
          : LoginPage(
              key: const ValueKey('login'),
              playIntro: _playIntro,
              onIntroDone: () => _playIntro = false,
            ),
    );
  }
}
