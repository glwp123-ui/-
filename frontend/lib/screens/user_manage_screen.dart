import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';
import '../utils/notion_theme.dart';

class UserManageScreen extends StatefulWidget {
  const UserManageScreen({super.key});

  @override
  State<UserManageScreen> createState() => _UserManageScreenState();
}

class _UserManageScreenState extends State<UserManageScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 항상 최신 유저 목록 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().reloadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: NotionTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('👑 계정 관리',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NotionTheme.textPrimary)),
            Text('마스터 전용 메뉴',
              style: TextStyle(fontSize: 11, color: NotionTheme.textSecondary)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showUserForm(context, null),
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('계정 추가', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: NotionTheme.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final users = auth.users;
          if (users.isEmpty) {
            return const Center(child: Text('등록된 계정이 없습니다'));
          }

          // 역할 순서: master → admin → user
          final sorted = [...users]..sort((a, b) => a.role.index.compareTo(b.role.index));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 역할별 설명 카드
              _RoleSummaryCard(),
              const SizedBox(height: 20),

              // 계정 목록 헤더
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text('전체 계정',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: NotionTheme.textSecondary, letterSpacing: 0.5)),
              ),

              ...sorted.map((user) => _UserCard(
                user: user,
                isSelf: auth.currentUser?.id == user.id,
                onEdit: () => _showUserForm(context, user),
                onDelete: () => _confirmDelete(context, auth, user),
                onToggleActive: () => _toggleActive(context, auth, user),
              )),
            ],
          );
        },
      ),
    );
  }

  void _showUserForm(BuildContext context, AppUser? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<AuthProvider>()),
          ChangeNotifierProvider.value(value: context.read<AppProvider>()),
        ],
        child: _UserFormSheet(editUser: user),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AuthProvider auth, AppUser user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Text(user.role.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text('${user.displayName} 삭제',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: NotionTheme.textPrimary, height: 1.6),
            children: [
              TextSpan(text: '${user.displayName}(${user.username})', style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ' 계정을\n'),
              const TextSpan(text: '정말 삭제하시겠습니까?',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: NotionTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await auth.deleteUser(user.id);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _toggleActive(BuildContext context, AuthProvider auth, AppUser user) async {
    final updated = user.copyWith(isActive: !user.isActive);
    final err = await auth.updateUser(updated);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red));
    }
  }
}

// ── 역할 설명 카드
class _RoleSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NotionTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('권한 안내', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: NotionTheme.textPrimary)),
          const SizedBox(height: 12),
          _RoleRow(emoji: '👑', role: '마스터', desc: '계정 관리 + 부서/업무 관리 + 모든 기능', color: const Color(0xFFCB912F)),
          const SizedBox(height: 8),
          _RoleRow(emoji: '🔑', role: '관리자', desc: '부서 관리 + 업무 배정/수정/삭제 + 보고 열람', color: NotionTheme.accent),
          const SizedBox(height: 8),
          _RoleRow(emoji: '👤', role: '사용자', desc: '업무 조회 + 상태 변경 + 중간 보고 작성', color: const Color(0xFF0F7B6C)),
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  final String emoji, role, desc;
  final Color color;
  const _RoleRow({required this.emoji, required this.role, required this.desc, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          Text(desc, style: const TextStyle(fontSize: 11, color: NotionTheme.textSecondary)),
        ],
      ),
    ],
  );
}

// ── 사용자 카드
class _UserCard extends StatefulWidget {
  final AppUser user;
  final bool isSelf;
  final VoidCallback onEdit, onDelete, onToggleActive;
  const _UserCard({required this.user, required this.isSelf,
    required this.onEdit, required this.onDelete, required this.onToggleActive});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _hover = false;

  Color get _roleColor {
    switch (widget.user.role) {
      case UserRole.master: return const Color(0xFFCB912F);
      case UserRole.admin:  return NotionTheme.accent;
      case UserRole.user:   return const Color(0xFF0F7B6C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInactive = !widget.user.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hover ? _roleColor.withValues(alpha: 0.4) : NotionTheme.border,
            width: _hover ? 1.5 : 1,
          ),
          boxShadow: _hover
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // 아바타
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: isInactive ? Colors.grey.shade100 : _roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(widget.user.role.emoji,
                        style: TextStyle(fontSize: 20,
                          color: isInactive ? Colors.grey.shade300 : null)),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // 이름 + 아이디
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(widget.user.displayName,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                                color: isInactive ? Colors.grey : NotionTheme.textPrimary)),
                            if (widget.isSelf) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: NotionTheme.accentLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('나', style: TextStyle(fontSize: 10,
                                  color: NotionTheme.accent, fontWeight: FontWeight.bold)),
                              ),
                            ],
                            if (isInactive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('비활성', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text('@${widget.user.username}',
                          style: const TextStyle(fontSize: 12, color: NotionTheme.textSecondary,
                            fontFamily: 'monospace')),
                      ],
                    ),
                  ),

                  // 역할 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _roleColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(widget.user.role.label,
                      style: TextStyle(fontSize: 12, color: _roleColor, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),

              // 액션 버튼 (hover 또는 항상 표시)
              if (_hover || widget.isSelf) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 활성/비활성 토글 (자기 자신 제외, 마스터 계정 제외)
                    if (!widget.isSelf && widget.user.role != UserRole.master)
                      _ActionChip(
                        icon: widget.user.isActive
                          ? Icons.block_outlined
                          : Icons.check_circle_outline,
                        label: widget.user.isActive ? '비활성화' : '활성화',
                        color: widget.user.isActive ? Colors.orange : const Color(0xFF0F7B6C),
                        onTap: widget.onToggleActive,
                      ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      icon: Icons.edit_outlined,
                      label: '수정',
                      color: NotionTheme.accent,
                      onTap: widget.onEdit,
                    ),
                    const SizedBox(width: 8),
                    // 삭제 (자기 자신 & 마스터 단독 계정 제외)
                    if (!widget.isSelf)
                      _ActionChip(
                        icon: Icons.delete_outline,
                        label: '삭제',
                        color: Colors.red.shade500,
                        onTap: widget.onDelete,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────
// 계정 추가/수정 폼 시트
// _────────────────────────────────────────
class _UserFormSheet extends StatefulWidget {
  final AppUser? editUser;
  const _UserFormSheet({this.editUser});

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _idCtrl;
  late TextEditingController _pwCtrl;
  late TextEditingController _pw2Ctrl;
  UserRole _role = UserRole.user;
  String? _deptId;
  bool _obscurePw  = true;
  bool _obscurePw2 = true;
  bool _loading    = false;

  bool get isEdit => widget.editUser != null;

  @override
  void initState() {
    super.initState();
    final u = widget.editUser;
    _nameCtrl = TextEditingController(text: u?.displayName ?? '');
    _idCtrl   = TextEditingController(text: u?.username ?? '');
    _pwCtrl   = TextEditingController(text: isEdit ? '' : '');
    _pw2Ctrl  = TextEditingController();
    _role     = u?.role ?? UserRole.user;
    _deptId   = u?.departmentId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _idCtrl.dispose();
    _pwCtrl.dispose();   _pw2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth  = context.read<AuthProvider>();
    final depts = context.read<AppProvider>().departments;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            const SizedBox(height: 10),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),

            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(isEdit ? '계정 수정' : '새 계정 추가',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: NotionTheme.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 20, color: NotionTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(),

            // 폼
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이름
                      _Label('이름 (표시명)'),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _deco('홍길동', Icons.badge_outlined),
                        validator: (v) => v == null || v.trim().isEmpty ? '이름을 입력하세요' : null,
                      ),
                      const SizedBox(height: 14),

                      // 아이디
                      _Label('로그인 아이디'),
                      TextFormField(
                        controller: _idCtrl,
                        decoration: _deco('아이디', Icons.person_outline),
                        validator: (v) => v == null || v.trim().isEmpty ? '아이디를 입력하세요' : null,
                      ),
                      const SizedBox(height: 14),

                      // 비밀번호
                      _Label(isEdit ? '새 비밀번호 (변경 시만 입력)' : '비밀번호'),
                      TextFormField(
                        controller: _pwCtrl,
                        obscureText: _obscurePw,
                        decoration: _deco('비밀번호', Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(_obscurePw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 17, color: NotionTheme.textSecondary),
                            onPressed: () => setState(() => _obscurePw = !_obscurePw),
                          ),
                        ),
                        validator: (v) {
                          if (!isEdit && (v == null || v.trim().isEmpty)) return '비밀번호를 입력하세요';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 비밀번호 확인
                      if (!isEdit || _pwCtrl.text.isNotEmpty) ...[
                        _Label('비밀번호 확인'),
                        TextFormField(
                          controller: _pw2Ctrl,
                          obscureText: _obscurePw2,
                          decoration: _deco('비밀번호 확인', Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(_obscurePw2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 17, color: NotionTheme.textSecondary),
                              onPressed: () => setState(() => _obscurePw2 = !_obscurePw2),
                            ),
                          ),
                          validator: (v) {
                            if (_pwCtrl.text.isNotEmpty && v != _pwCtrl.text) return '비밀번호가 일치하지 않습니다';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 권한 선택
                      _Label('권한'),
                      const SizedBox(height: 8),
                      Row(
                        children: UserRole.values.map((r) {
                          // 마스터 역할은 마스터만 볼 수 있으나 수정은 자기 자신 제외
                          final isSel = _role == r;
                          Color col;
                          switch (r) {
                            case UserRole.master: col = const Color(0xFFCB912F); break;
                            case UserRole.admin:  col = NotionTheme.accent; break;
                            case UserRole.user:   col = const Color(0xFF0F7B6C); break;
                          }
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _role = r),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel ? col.withValues(alpha: 0.1) : const Color(0xFFF7F7F5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel ? col : NotionTheme.border,
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text(r.emoji, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(height: 3),
                                  Text(r.label,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                      color: isSel ? col : NotionTheme.textSecondary)),
                                ]),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // 소속 부서 (사용자 역할일 때)
                      if (_role == UserRole.user) ...[
                        _Label('소속 부서 (선택)'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _pickDept(context, depts),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: _deptId != null ? NotionTheme.accentLight : const Color(0xFFF7F7F5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _deptId != null ? NotionTheme.accent : NotionTheme.border),
                            ),
                            child: Row(children: [
                              Icon(Icons.business_outlined, size: 16,
                                color: _deptId != null ? NotionTheme.accent : NotionTheme.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(
                                _deptId != null
                                  ? _deptName(depts, _deptId!)
                                  : '부서 선택 (선택사항)',
                                style: TextStyle(fontSize: 13,
                                  color: _deptId != null ? NotionTheme.accent : NotionTheme.textSecondary),
                              )),
                              if (_deptId != null)
                                GestureDetector(
                                  onTap: () => setState(() => _deptId = null),
                                  child: const Icon(Icons.close, size: 14, color: NotionTheme.textSecondary),
                                ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 저장 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _loading ? null : () => _save(context, auth),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NotionTheme.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _loading
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isEdit ? '저장' : '계정 추가',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _deptName(List depts, String id) {
    try {
      final d = depts.firstWhere((d) => d.id == id);
      return '${d.emoji} ${d.name}';
    } catch (_) { return '알 수 없는 부서'; }
  }

  void _pickDept(BuildContext context, List depts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          const Text('소속 부서 선택', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...depts.map((d) => ListTile(
            leading: Text(d.emoji, style: const TextStyle(fontSize: 20)),
            title: Text(d.name),
            trailing: _deptId == d.id ? const Icon(Icons.check, color: NotionTheme.accent) : null,
            onTap: () { setState(() => _deptId = d.id); Navigator.pop(context); },
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _save(BuildContext context, AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    String? err;
    if (isEdit) {
      final updated = widget.editUser!.copyWith(
        displayName: _nameCtrl.text.trim(),
        username: _idCtrl.text.trim(),
        password: _pwCtrl.text.trim().isEmpty ? widget.editUser!.password : _pwCtrl.text.trim(),
        role: _role,
        departmentId: _deptId,
      );
      err = await auth.updateUser(updated);
    } else {
      err = await auth.addUser(
        username: _idCtrl.text.trim(),
        password: _pwCtrl.text.trim(),
        displayName: _nameCtrl.text.trim(),
        role: _role,
        departmentId: _deptId,
      );
    }

    if (mounted) {
      setState(() => _loading = false);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEdit ? '계정이 수정되었습니다' : '계정이 추가되었습니다'),
          backgroundColor: const Color(0xFF0F7B6C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    }
  }

  Widget _Label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NotionTheme.textPrimary)),
  );

  InputDecoration _deco(String hint, IconData icon, {Widget? suffix}) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 17, color: NotionTheme.textSecondary),
    suffixIcon: suffix,
    filled: true,
    fillColor: const Color(0xFFF7F7F5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: NotionTheme.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: NotionTheme.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: NotionTheme.accent, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.red.shade400)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );
}
