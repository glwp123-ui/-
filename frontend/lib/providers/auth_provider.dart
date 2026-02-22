import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  List<AppUser> _users = [];
  AppUser?      _currentUser;
  bool          _isLoading = true;

  AppUser?          get currentUser => _currentUser;
  bool              get isLoggedIn  => _currentUser != null;
  bool              get isLoading   => _isLoading;
  List<AppUser>     get users       => List.unmodifiable(_users);

  // 권한 게터
  bool get isMaster        => _currentUser?.role == UserRole.master;
  bool get isAdmin         => _currentUser?.role == UserRole.admin || isMaster;
  bool get canManageDept   => true;  // 모든 역할
  bool get canManageTask   => true;  // 모든 역할
  bool get canManageUsers  => isMaster;
  bool get canViewHistory  => isMaster || isAdmin;

  static const _kToken  = 'sw_api_token';
  static const _kUserId = 'sw_user_id';

  // ── 초기화: 저장된 토큰으로 자동 로그인 ───────────
  Future<void> load() async {
    _isLoading = true; notifyListeners();
    try {
      final p     = await SharedPreferences.getInstance();
      final token = p.getString(_kToken);
      if (token != null && token.isNotEmpty) {
        api.setToken(token);
        try {
          // ⚡ 8초 타임아웃: 서버 슬립 중이어도 빠르게 로그인 화면으로 이동
          final me = await api.get('/auth/me')
              .timeout(const Duration(seconds: 8));
          _currentUser = AppUser.fromJson(me);
          // 전체 사용자 목록도 로드 (마스터 권한이면) - 백그라운드
          if (_currentUser!.role == UserRole.master ||
              _currentUser!.role == UserRole.admin) {
            _loadUsers(); // await 없이 백그라운드 실행
          }
        } catch (_) {
          // 토큰 만료 또는 서버 응답 없음 → 로그인 화면으로
          api.setToken(null);
          await p.remove(_kToken);
          await p.remove(_kUserId);
          _currentUser = null;
        }
      }
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  // ── 로그인 ────────────────────────────────────────
  Future<String?> login(String username, String password) async {
    try {
      final data = await api.login(username.trim(), password.trim());
      _currentUser = AppUser.fromJson(data['user']);
      // 토큰 저장
      final p = await SharedPreferences.getInstance();
      await p.setString(_kToken,  data['access_token']);
      await p.setString(_kUserId, _currentUser!.id);
      // 마스터/관리자면 사용자 목록 로드
      if (_currentUser!.role == UserRole.master ||
          _currentUser!.role == UserRole.admin) { await _loadUsers(); }
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return '서버 연결에 실패했습니다. 백엔드 서버를 확인해주세요.';
    }
  }

  // ── 로그아웃 ──────────────────────────────────────
  Future<void> logout() async {
    _currentUser = null;
    _users = [];
    api.setToken(null);
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUserId);
    notifyListeners();
  }

  // ── 사용자 목록 로드 ──────────────────────────────
  Future<void> _loadUsers() async {
    try {
      final data = await api.getUsers();
      _users = data.map((u) => AppUser.fromJson(u)).toList();
    } catch (_) {}
  }

  Future<void> reloadUsers() async {
    await _loadUsers();
    notifyListeners();
  }

  // ── 사용자 추가 ───────────────────────────────────
  Future<String?> addUser({
    required String username,
    required String password,
    required String displayName,
    required UserRole role,
    String? departmentId,
  }) async {
    try {
      final data = await api.createUser({
        'username': username.trim(),
        'password': password.trim(),
        'display_name': displayName.trim(),
        'role': role.name,
        if (departmentId != null) 'dept_id': departmentId,
      });
      _users.add(AppUser.fromJson(data));
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  // ── 사용자 수정 ───────────────────────────────────
  Future<String?> updateUser(AppUser updated) async {
    try {
      final data = await api.updateUser(updated.id, {
        'username':     updated.username,
        'display_name': updated.displayName,
        'role':         updated.role.name,
        'dept_id':      updated.departmentId,
        'is_active':    updated.isActive,
      });
      final upd = AppUser.fromJson(data);
      final i   = _users.indexWhere((u) => u.id == upd.id);
      if (i != -1) _users[i] = upd;
      if (_currentUser?.id == upd.id) _currentUser = upd;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  // ── 사용자 삭제 ───────────────────────────────────
  Future<String?> deleteUser(String userId) async {
    try {
      await api.deleteUser(userId);
      _users.removeWhere((u) => u.id == userId);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  // ── 비밀번호 변경 ─────────────────────────────────
  Future<String?> changePassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await api.changePassword(userId, newPassword.trim());
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}
