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

/// 로그인 상태에 따라 화면 분기 + 로그인 시 데이터 자동 새로고침
class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool _wasLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final appProv = context.read<AppProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 로그인 상태가 바뀐 순간(로그아웃→로그인) 데이터 자동 새로고침
    if (auth.isLoggedIn && !_wasLoggedIn) {
      _wasLoggedIn = true;
      // 프레임 이후에 실행 (build 중 setState 방지)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appProv.load();
      });
    } else if (!auth.isLoggedIn) {
      _wasLoggedIn = false;
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    return const MainScreen();
  }
}
