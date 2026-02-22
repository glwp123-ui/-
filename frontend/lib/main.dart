import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'utils/notion_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final appProvider  = AppProvider();
  final authProvider = AuthProvider();

  // ⚡ 네트워크 요청을 main()에서 await 하지 않음 → 즉시 화면 표시
  // authProvider가 비동기로 로드하면서 isLoading=true → 완료 후 화면 전환
  authProvider.load();

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

    // 인증 로딩 중 → 스플래시 화면 (즉시 표시, 네트워크 응답 기다림)
    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🏥', style: TextStyle(fontSize: 52)),
              SizedBox(height: 16),
              Text('song work',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                  color: Color(0xFF37352F))),
              SizedBox(height: 24),
              SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2,
                  color: Color(0xFF2383E2)),
              ),
            ],
          ),
        ),
      );
    }

    // 로그인 상태가 바뀐 순간(로그아웃→로그인) 데이터 자동 새로고침
    if (auth.isLoggedIn && !_wasLoggedIn) {
      _wasLoggedIn = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 담당자 필터 정보 주입: user 역할이면 본인 업무만, admin/master는 전체
        final user = auth.currentUser!;
        final isAdminOrAbove = user.role == UserRole.admin || user.role == UserRole.master;
        appProv.setCurrentUser(user.displayName, isAdminOrAbove);
        appProv.load();
      });
    } else if (!auth.isLoggedIn) {
      _wasLoggedIn = false;
      // 로그아웃 시 필터 초기화
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appProv.setCurrentUser(null, true);
      });
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    return const MainScreen();
  }
}
