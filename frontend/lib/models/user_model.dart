// ───────────────────────────────────────────
// 권한(역할) 정의
// ───────────────────────────────────────────
enum UserRole { master, admin, user }

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.master: return '마스터';
      case UserRole.admin:  return '관리자';
      case UserRole.user:   return '사용자';
    }
  }

  String get emoji {
    switch (this) {
      case UserRole.master: return '👑';
      case UserRole.admin:  return '🔑';
      case UserRole.user:   return '👤';
    }
  }

  // 부서 추가/삭제 가능? → 모든 역할 허용
  bool get canManageDept => true;

  // 업무 추가/수정/삭제 가능? → 모든 역할 허용
  bool get canManageTask => true;

  // 중간 보고 작성 가능? → 모든 역할 허용
  bool get canReport => true;

  // 일일 보고 열람 가능? → 모든 역할 허용
  bool get canViewDailyReport => true;

  // 계정 관리 가능? (사용자 추가/삭제) → 마스터만
  bool get canManageUsers => this == UserRole.master;
}

// ───────────────────────────────────────────
// AppUser
// ───────────────────────────────────────────
class AppUser {
  final String id;
  String username;   // 로그인 아이디
  String password;   // 평문 저장 (소규모 내부 앱용)
  String displayName; // 표시 이름
  UserRole role;
  String? departmentId; // 사용자가 속한 부서 (user 역할 시)
  bool isActive;

  AppUser({
    required this.id,
    required this.username,
    required this.password,
    required this.displayName,
    required this.role,
    this.departmentId,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'password': password,
    'displayName': displayName,
    'role': role.index,
    'departmentId': departmentId,
    'isActive': isActive,
  };

  factory AppUser.fromJson(Map<String, dynamic> j) {
    // role: API는 문자열("master"/"admin"/"user"), 로컬은 int index
    UserRole parseRole(dynamic r) {
      if (r is String) {
        return UserRole.values.firstWhere((v) => v.name == r,
            orElse: () => UserRole.user);
      }
      return UserRole.values[r ?? 2];
    }
    return AppUser(
      id: j['id'],
      username: j['username'],
      password: j['password'] ?? '',          // API 응답엔 password 없을 수 있음
      displayName: j['display_name'] ?? j['displayName'] ?? '',
      role: parseRole(j['role']),
      departmentId: j['dept_id'] ?? j['departmentId'],
      isActive: j['is_active'] ?? j['isActive'] ?? true,
    );
  }

  AppUser copyWith({
    String? username,
    String? password,
    String? displayName,
    UserRole? role,
    String? departmentId,
    bool? isActive,
  }) => AppUser(
    id: id,
    username: username ?? this.username,
    password: password ?? this.password,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    departmentId: departmentId ?? this.departmentId,
    isActive: isActive ?? this.isActive,
  );
}
