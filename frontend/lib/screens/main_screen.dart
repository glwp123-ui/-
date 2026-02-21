import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/notion_theme.dart';
import '../widgets/notion_sidebar.dart';
import '../widgets/task_detail_sheet.dart';
import 'board_view.dart';
import 'list_view_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: NotionTheme.mainBg,
          body: SafeArea(
            child: Row(
              children: [
                // ── 사이드바
                if (provider.isSidebarOpen)
                  const NotionSidebar(),

                // ── 메인 콘텐츠
                Expanded(
                  child: Column(
                    children: [
                      // ── 상단 툴바
                      _TopBar(),
                      const Divider(height: 1),
                      // ── 뷰 콘텐츠
                      Expanded(
                        child: provider.viewMode == ViewMode.board
                          ? _BoardWrapper()
                          : const ListViewScreen(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: _AddTaskFAB(),
        );
      },
    );
  }
}

// ── 상단 툴바
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: NotionTheme.mainBg,
          child: Row(
            children: [
              // 사이드바 토글
              if (!provider.isSidebarOpen)
                IconButton(
                  onPressed: provider.toggleSidebar,
                  icon: const Icon(Icons.menu, size: 18, color: NotionTheme.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28),
                ),

              // 페이지 제목 (이모지 + 이름)
              if (!provider.isSidebarOpen) const SizedBox(width: 8),
              Text(provider.currentPageEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.currentPageTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: NotionTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 통계 뱃지
              _StatBadge(
                icon: Icons.timelapse_rounded,
                count: provider.selectedDeptId == null
                  ? provider.totalInProgress
                  : provider.deptCount(provider.selectedDeptId!, TaskStatus.inProgress),
                color: TaskStatus.inProgress.color,
              ),
              const SizedBox(width: 4),

              // 뷰 전환 버튼
              const SizedBox(width: 8),
              _ViewToggle(),

              // 업무 추가 버튼 (관리자/마스터만)
              const SizedBox(width: 6),
              if (context.watch<AuthProvider>().canManageTask)
                _TopAddButton(),
            ],
          ),
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  const _StatBadge({required this.icon, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: NotionTheme.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: NotionTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.view_kanban_outlined,
            label: '보드',
            selected: provider.viewMode == ViewMode.board,
            onTap: () { if (provider.viewMode != ViewMode.board) provider.toggleViewMode(); },
          ),
          Container(width: 1, height: 20, color: NotionTheme.border),
          _ToggleBtn(
            icon: Icons.format_list_bulleted,
            label: '목록',
            selected: provider.viewMode == ViewMode.list,
            onTap: () { if (provider.viewMode != ViewMode.list) provider.toggleViewMode(); },
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleBtn({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 3)] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: selected ? NotionTheme.textPrimary : NotionTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12,
            color: selected ? NotionTheme.textPrimary : NotionTheme.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    ),
  );
}

class _TopAddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _addTask(context),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: NotionTheme.accent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text('추가', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _addTask(BuildContext context) {
    final provider = context.read<AppProvider>();
    final deptId = provider.selectedDeptId ?? (provider.departments.isNotEmpty ? provider.departments.first.id : null);
    if (deptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 사이드바에서 부서를 추가해주세요 →')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TaskFormPage(preselectedDeptId: deptId),
    ));
  }
}

// ── 보드 뷰 래퍼 (스크롤 + 패딩)
class _BoardWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final notStarted = provider.getTasksByStatus(TaskStatus.notStarted);
        final inProgress = provider.getTasksByStatus(TaskStatus.inProgress);
        final done = provider.getTasksByStatus(TaskStatus.done);
        final isEmpty = notStarted.isEmpty && inProgress.isEmpty && done.isEmpty;

        if (isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(provider.currentPageEmoji, style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 12),
                Text(
                  '${provider.currentPageTitle}에 업무가 없습니다',
                  style: const TextStyle(fontSize: 16, color: NotionTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                const Text('우측 상단 추가 버튼 또는 각 컬럼의 + 버튼을 눌러 업무를 추가하세요',
                  style: TextStyle(fontSize: 12, color: NotionTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: MediaQuery.of(context).size.width > 700
                ? MediaQuery.of(context).size.width - (provider.isSidebarOpen ? 270 : 30)
                : 700,
              child: IntrinsicHeight(
                child: const BoardView(),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── FAB (관리자/마스터만)
class _AddTaskFAB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.canManageTask) return const SizedBox.shrink();
    return FloatingActionButton(
      onPressed: () => _addTask(context),
      backgroundColor: NotionTheme.accent,
      foregroundColor: Colors.white,
      elevation: 2,
      child: const Icon(Icons.add),
    );
  }

  void _addTask(BuildContext context) {
    final provider = context.read<AppProvider>();
    final deptId = provider.selectedDeptId ?? (provider.departments.isNotEmpty ? provider.departments.first.id : null);
    if (deptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 부서를 추가해주세요')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TaskFormPage(preselectedDeptId: deptId),
    ));
  }
}
