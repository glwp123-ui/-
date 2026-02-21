import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../models/user_model.dart';
import '../utils/notion_theme.dart';
import '../screens/calendar_screen.dart';
import '../screens/completed_history_screen.dart';
import '../screens/daily_report_screen.dart';
import '../screens/user_manage_screen.dart';
import 'dept_form_sheet.dart';

class NotionSidebar extends StatefulWidget {
  const NotionSidebar({super.key});

  @override
  State<NotionSidebar> createState() => _NotionSidebarState();
}

class _NotionSidebarState extends State<NotionSidebar> {
  bool _isSyncing = false;

  Future<void> _syncData(BuildContext context) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await context.read<AppProvider>().load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('데이터가 최신 상태로 동기화되었습니다.'),
              ],
            ),
            backgroundColor: const Color(0xFF0F7B6C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('동기화에 실패했습니다. 다시 시도해주세요.'),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final auth     = context.watch<AuthProvider>();
    final canManageDept = auth.canManageDept;

    return Container(
      width: 248,
      color: NotionTheme.sidebarBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 워크스페이스 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
              child: Row(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: NotionTheme.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(child: Text('🏥', style: TextStyle(fontSize: 14))),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('song work',
                      style: TextStyle(color: NotionTheme.sidebarText,
                        fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  ),
                  // 동기화 버튼
                  _isSyncing
                    ? const SizedBox(
                        width: 28, height: 28,
                        child: Center(
                          child: SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF5DA3E8),
                            ),
                          ),
                        ),
                      )
                    : _SidebarIconBtn(
                        icon: Icons.sync_rounded,
                        tooltip: '데이터 동기화 (새로고침)',
                        onTap: () => _syncData(context),
                      ),
                  _SidebarIconBtn(
                    icon: Icons.keyboard_double_arrow_left,
                    tooltip: '사이드바 닫기',
                    onTap: () => provider.toggleSidebar(),
                  ),
                ],
              ),
            ),

            // ── 현재 로그인 사용자 정보
            _CurrentUserTile(auth: auth),

            const SizedBox(height: 4),

            // ── 전체 업무 (홈)
            _SidebarItem(
              emoji: '🏠',
              label: '전체 업무',
              isSelected: provider.selectedDeptId == null,
              badge: provider.totalAll,
              onTap: () => provider.selectDept(null),
            ),

            // ── 전체 통계 미니뷰
            if (provider.selectedDeptId == null)
              _MiniStats(provider: provider),

            // ── 달력 버튼
            _CalendarButton(provider: provider),

            // ── 일일 보고 버튼
            _DailyReportButton(provider: provider),

            // ── 완료 업무 보관함 (마스터+관리자만)
            if (auth.canViewHistory)
              _HistoryButton(provider: provider),

            const SizedBox(height: 4),

            // ── 부서 섹션 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
              child: Row(
                children: [
                  const Text('부서',
                    style: TextStyle(color: NotionTheme.sidebarSubtext,
                      fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                  const Spacer(),
                  // 관리자/마스터만 부서 추가 가능
                  if (canManageDept)
                    Tooltip(
                      message: '부서 추가',
                      child: GestureDetector(
                        onTap: () => showDeptFormSheet(context, provider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: NotionTheme.accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 12, color: Color(0xFF5DA3E8)),
                              SizedBox(width: 3),
                              Text('추가', style: TextStyle(fontSize: 11,
                                color: Color(0xFF5DA3E8), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── 부서 목록
            Expanded(
              child: provider.departments.isEmpty
                ? _EmptyDeptHint(onAdd: canManageDept
                    ? () => showDeptFormSheet(context, provider) : null)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: provider.departments.length,
                    itemBuilder: (_, i) {
                      final dept = provider.departments[i];
                      final isSelected = provider.selectedDeptId == dept.id;
                      final total = provider.deptTotal(dept.id);
                      return _DeptSidebarItem(
                        dept: dept,
                        isSelected: isSelected,
                        badge: total,
                        canManage: canManageDept,
                        onTap: () => provider.selectDept(dept.id),
                        onEdit:   canManageDept ? () => showDeptFormSheet(context, provider, dept) : null,
                        onDelete: canManageDept ? () => _confirmDeleteDept(context, provider, dept) : null,
                      );
                    },
                  ),
            ),

            // ── 하단 구분선
            Container(height: 1, color: NotionTheme.sidebarDivider),

            // ── 관리자/마스터: 부서 추가 버튼
            if (canManageDept)
              GestureDetector(
                onTap: () => showDeptFormSheet(context, provider),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: NotionTheme.sidebarHover,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NotionTheme.sidebarDivider),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 15, color: Color(0xFF5DA3E8)),
                      SizedBox(width: 8),
                      Text('새 부서 추가', style: TextStyle(color: Color(0xFF5DA3E8),
                        fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),

            // ── 마스터: 계정 관리 버튼
            if (auth.isMaster)
              _AccountManageButton(auth: auth),

            // ── 수동 동기화 버튼
            _ManualSyncButton(
              isSyncing: _isSyncing,
              onSync: () => _syncData(context),
            ),

            // ── 로그아웃 버튼
            _LogoutButton(auth: auth),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDept(BuildContext context, AppProvider provider, Department dept) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Text(dept.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text('${dept.name} 삭제', style: const TextStyle(fontSize: 16))),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: NotionTheme.textPrimary, height: 1.5),
            children: [
              TextSpan(text: dept.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ' 부서를 삭제하면\n해당 부서의 '),
              const TextSpan(text: '모든 업무도 함께 삭제',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const TextSpan(text: '됩니다.\n정말 삭제하시겠습니까?'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: NotionTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)), elevation: 0),
            onPressed: () { provider.deleteDepartment(dept.id); Navigator.pop(context); },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ── 현재 로그인 사용자 타일
class _CurrentUserTile extends StatelessWidget {
  final AuthProvider auth;
  const _CurrentUserTile({required this.auth});

  Color get _roleColor {
    switch (auth.currentUser?.role) {
      case UserRole.master: return const Color(0xFFCB912F);
      case UserRole.admin:  return NotionTheme.accent;
      default:              return const Color(0xFF0F7B6C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _roleColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _roleColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(child: Text(user.role.emoji, style: const TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  overflow: TextOverflow.ellipsis),
                Text(user.role.label,
                  style: TextStyle(fontSize: 10, color: _roleColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 마스터: 계정 관리 버튼
class _AccountManageButton extends StatefulWidget {
  final AuthProvider auth;
  const _AccountManageButton({required this.auth});

  @override
  State<_AccountManageButton> createState() => _AccountManageButtonState();
}

class _AccountManageButtonState extends State<_AccountManageButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: widget.auth),
              ChangeNotifierProvider.value(value: context.read<AppProvider>()),
            ],
            child: const UserManageScreen(),
          ),
        )),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _hover
              ? const Color(0xFFB8882A).withValues(alpha: 0.9)
              : const Color(0xFFCB912F).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Text('👑', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('계정 관리',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Text('${widget.auth.users.length}명',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 14, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 로그아웃 버튼
class _LogoutButton extends StatefulWidget {
  final AuthProvider auth;
  const _LogoutButton({required this.auth});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => _confirmLogout(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _hover
              ? Colors.red.withValues(alpha: 0.2)
              : NotionTheme.sidebarHover,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 15,
                color: _hover ? Colors.red.shade300 : NotionTheme.sidebarIcon),
              const SizedBox(width: 8),
              Text('로그아웃',
                style: TextStyle(
                  color: _hover ? Colors.red.shade300 : NotionTheme.sidebarText,
                  fontSize: 13)),
              const Spacer(),
              Text(widget.auth.currentUser?.username ?? '',
                style: const TextStyle(color: NotionTheme.sidebarSubtext, fontSize: 11,
                  fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('로그아웃', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('${widget.auth.currentUser?.displayName ?? ''}님,\n정말 로그아웃 하시겠습니까?',
          style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: NotionTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(context);
              await widget.auth.logout();
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}

// ── 완료 업무 보관함 버튼 (마스터+관리자)
class _HistoryButton extends StatefulWidget {
  final AppProvider provider;
  const _HistoryButton({required this.provider});

  @override
  State<_HistoryButton> createState() => _HistoryButtonState();
}

class _HistoryButtonState extends State<_HistoryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final doneCount = widget.provider.tasks
        .where((t) => t.status == TaskStatus.done).length;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: widget.provider),
                ChangeNotifierProvider.value(
                  value: context.read<AuthProvider>()),
              ],
              child: const CompletedHistoryScreen(),
            ),
          ));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.fromLTRB(6, 4, 6, 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hover
              ? const Color(0xFF0A6055).withValues(alpha: 0.9)
              : const Color(0xFF0F7B6C).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Text('🗂️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('완료 보관함',
                  style: TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w600)),
              ),
              if (doneCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$doneCount',
                    style: const TextStyle(color: Colors.white,
                      fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 14,
                color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 달력 버튼
class _CalendarButton extends StatefulWidget {
  final AppProvider provider;
  const _CalendarButton({required this.provider});

  @override
  State<_CalendarButton> createState() => _CalendarButtonState();
}

class _CalendarButtonState extends State<_CalendarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // 이번 달 마감 업무 수
    final now = DateTime.now();
    final monthDueCount = widget.provider
        .getMonthlyDueTasks(now.year, now.month)
        .values
        .fold(0, (s, v) => s + v.length);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: widget.provider),
                ChangeNotifierProvider.value(value: context.read<AuthProvider>()),
              ],
              child: const CalendarScreen(),
            ),
          ));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.fromLTRB(6, 4, 6, 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hover
              ? const Color(0xFF5044B8).withValues(alpha: 0.9)
              : const Color(0xFF6C5FD4).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('업무 달력',
                  style: TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w600)),
              ),
              if (monthDueCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$monthDueCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 14, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 일일 보고 버튼
class _DailyReportButton extends StatefulWidget {
  final AppProvider provider;
  const _DailyReportButton({required this.provider});

  @override
  State<_DailyReportButton> createState() => _DailyReportButtonState();
}

class _DailyReportButtonState extends State<_DailyReportButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final todayCount = widget.provider.todayReportableCount;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: widget.provider),
                ChangeNotifierProvider.value(value: context.read<AuthProvider>()),
              ],
              child: const DailyReportScreen(),
            ),
          ));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.fromLTRB(6, 4, 6, 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hover
              ? const Color(0xFF1A5C50).withValues(alpha: 0.9)
              : const Color(0xFF0F7B6C).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('일일 보고',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (todayCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$todayCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 14, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 부서 사이드바 아이템
class _DeptSidebarItem extends StatefulWidget {
  final Department dept;
  final bool isSelected;
  final bool canManage;
  final int badge;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _DeptSidebarItem({
    required this.dept, required this.isSelected, required this.badge,
    required this.canManage, required this.onTap,
    this.onEdit, this.onDelete,
  });

  @override
  State<_DeptSidebarItem> createState() => _DeptSidebarItemState();
}

class _DeptSidebarItemState extends State<_DeptSidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected ? NotionTheme.sidebarActive
              : _hover ? NotionTheme.sidebarHover : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Text(widget.dept.emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.dept.name,
                  style: TextStyle(
                    color: widget.isSelected ? Colors.white : NotionTheme.sidebarText,
                    fontSize: 13,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal),
                  overflow: TextOverflow.ellipsis),
              ),
              // 관리자/마스터: hover 시 수정·삭제 버튼
              if (widget.canManage && (_hover || widget.isSelected)) ...[
                if (widget.onEdit != null)
                  _ItemActionBtn(icon: Icons.edit_outlined, tooltip: '부서 수정',
                    onTap: widget.onEdit!, isSelected: widget.isSelected),
                const SizedBox(width: 2),
                if (widget.onDelete != null)
                  _ItemActionBtn(icon: Icons.delete_outline, tooltip: '부서 삭제',
                    onTap: widget.onDelete!, isSelected: widget.isSelected, isDanger: true),
              ] else if (widget.badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: NotionTheme.sidebarActive, borderRadius: BorderRadius.circular(10)),
                  child: Text('${widget.badge}',
                    style: const TextStyle(color: NotionTheme.sidebarSubtext,
                      fontSize: 10, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemActionBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isDanger;
  const _ItemActionBtn({required this.icon, required this.tooltip, required this.onTap,
    required this.isSelected, this.isDanger = false});

  @override
  State<_ItemActionBtn> createState() => _ItemActionBtnState();
}

class _ItemActionBtnState extends State<_ItemActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final baseColor  = widget.isSelected ? Colors.white70 : NotionTheme.sidebarIcon;
    final hoverColor = widget.isDanger ? Colors.red.shade300 : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: _hover
                ? (widget.isDanger ? Colors.red.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.15))
                : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(widget.icon, size: 13, color: _hover ? hoverColor : baseColor),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final String? emoji;
  final String label;
  final bool isSelected;
  final int? badge;
  final VoidCallback onTap;
  const _SidebarItem({this.emoji, required this.label, required this.isSelected, this.badge, required this.onTap});

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected ? NotionTheme.sidebarActive
              : _hover ? NotionTheme.sidebarHover : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              if (widget.emoji != null)
                Text(widget.emoji!, style: const TextStyle(fontSize: 15))
              else
                const Icon(Icons.folder_outlined, size: 15, color: NotionTheme.sidebarIcon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.label,
                  style: TextStyle(
                    color: widget.isSelected ? Colors.white : NotionTheme.sidebarText,
                    fontSize: 13,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal),
                  overflow: TextOverflow.ellipsis),
              ),
              if (widget.badge != null && widget.badge! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.isSelected ? Colors.white24 : NotionTheme.sidebarActive,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${widget.badge}',
                    style: TextStyle(
                      color: widget.isSelected ? Colors.white : NotionTheme.sidebarSubtext,
                      fontSize: 10, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarIconBtn extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  const _SidebarIconBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? '',
    child: GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: NotionTheme.sidebarIcon),
      ),
    ),
  );
}

class _MiniStats extends StatelessWidget {
  final AppProvider provider;
  const _MiniStats({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: NotionTheme.sidebarActive, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MiniStat('미시작', provider.totalNotStarted, const Color(0xFF9B9B9B)),
          _VertDivider(),
          _MiniStat('진행중', provider.totalInProgress, const Color(0xFF5DA3E8)),
          _VertDivider(),
          _MiniStat('완료', provider.totalDone, const Color(0xFF4FAFA0)),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
    Container(width: 1, height: 28, color: NotionTheme.sidebarDivider);
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _MiniStat(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 1),
      Text(label, style: const TextStyle(color: NotionTheme.sidebarSubtext, fontSize: 10)),
    ],
  );
}

// ── 수동 동기화(저장) 버튼
class _ManualSyncButton extends StatefulWidget {
  final bool isSyncing;
  final VoidCallback onSync;
  const _ManualSyncButton({required this.isSyncing, required this.onSync});

  @override
  State<_ManualSyncButton> createState() => _ManualSyncButtonState();
}

class _ManualSyncButtonState extends State<_ManualSyncButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.isSyncing ? null : widget.onSync,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _hover
              ? const Color(0xFF3A7BD5).withValues(alpha: 0.25)
              : const Color(0xFF5DA3E8).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF5DA3E8).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              widget.isSyncing
                ? const SizedBox(
                    width: 15, height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF5DA3E8)),
                  )
                : const Icon(Icons.cloud_sync_rounded,
                    size: 15, color: Color(0xFF5DA3E8)),
              const SizedBox(width: 8),
              Text(
                widget.isSyncing ? '동기화 중...' : '데이터 저장 / 새로고침',
                style: const TextStyle(
                  color: Color(0xFF5DA3E8),
                  fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (!widget.isSyncing)
                const Icon(Icons.sync_rounded,
                  size: 13, color: Color(0xFF5DA3E8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDeptHint extends StatelessWidget {
  final VoidCallback? onAdd;
  const _EmptyDeptHint({this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        const Text('🏥', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        const Text('부서가 없습니다',
          style: TextStyle(color: NotionTheme.sidebarSubtext, fontSize: 12)),
        if (onAdd != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: NotionTheme.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
              child: const Text('+ 부서 추가',
                style: TextStyle(color: Color(0xFF5DA3E8), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    ),
  );
}
