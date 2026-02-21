import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'utils/notion_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appProvider  = AppProvider();
  final authProvider = AuthProvider();

  await Future.wait([
    appProvider.load(),
    authProvider.load(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider.value(value: authProvider),
      ],
      child: const SongWorkApp(),
    ),
  );
}

class SongWorkApp extends StatelessWidget {
  const SongWorkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'song work',
      debugShowCheckedModeBanner: false,
      theme: NotionTheme.theme,
      home: const _RootRouter(),
    );
  }
}

/// 로그인 상태에 따라 화면 분기
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    return const MainScreen();
  }
}
