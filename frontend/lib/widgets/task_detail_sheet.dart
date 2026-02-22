import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/user_model.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/notion_theme.dart';

void showTaskDetail(BuildContext context, Task task) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: context.read<AppProvider>()),
        ChangeNotifierProvider.value(value: context.read<AuthProvider>()),
      ],
      child: _TaskDetailSheet(task: task),
    ),
  );
}

class _TaskDetailSheet extends StatefulWidget {
  final Task task;
  const _TaskDetailSheet({required this.task});

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> with SingleTickerProviderStateMixin {
  late Task _task;
  late TabController _tabCtrl;
  final _reportCtrl = TextEditingController();
  final _reporterCtrl = TextEditingController();


  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _reportCtrl.dispose();
    _reporterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    // 최신 task 데이터 반영
    final freshTask = provider.tasks.firstWhere((t) => t.id == _task.id, orElse: () => _task);
    _task = freshTask;
    final dept = provider.getDeptById(_task.departmentId);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // 핸들
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),

            // 상단 액션바
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _StatusPill(task: _task, onChanged: (s) async {
                    final prov = context.read<AppProvider>();
                    await prov.updateTaskStatus(_task.id, s);
                  }),
                  const Spacer(),
                  _ActionBtn(icon: Icons.edit_outlined, label: '수정', onTap: () {
                    Navigator.pop(context);
                    _openEditForm(context, _task);
                  }),
                  const SizedBox(width: 8),
                  _ActionBtn(icon: Icons.delete_outline, label: '삭제', color: Colors.red.shade400, onTap: () {
                    context.read<AppProvider>().deleteTask(_task.id);
                    Navigator.pop(context);
                  }),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 탭 바
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: NotionTheme.accent,
                unselectedLabelColor: NotionTheme.textSecondary,
                indicatorColor: NotionTheme.accent,
                indicatorWeight: 2,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                tabs: [
                  const Tab(text: '업무 정보'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('중간 보고'),
                        if (_task.reports.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: NotionTheme.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${_task.reports.length}',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── 탭 1: 업무 정보
                  ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      Text(_task.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                          color: NotionTheme.textPrimary, height: 1.3)),
                      const SizedBox(height: 20),
                      _PropertyRow(label: '부서', child: dept != null
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(dept.emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(dept.name, style: const TextStyle(fontSize: 14, color: NotionTheme.textPrimary)),
                          ])
                        : const Text('없음', style: TextStyle(color: NotionTheme.textMuted))),
                      _PropertyRow(label: '상태', child: _StatusChip(status: _task.status)),
                      _PropertyRow(label: '우선순위', child: _PriorityChip(priority: _task.priority)),
                      _PropertyRow(label: '담당자', child: _buildAssigneeDisplay(context, provider)),
                      _PropertyRow(label: '마감일', child: _task.dueDate != null
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.calendar_today_outlined, size: 13,
                              color: _task.isOverdue ? Colors.red : NotionTheme.textSecondary),
                            const SizedBox(width: 5),
                            Text(_fmtDate(_task.dueDate!),
                              style: TextStyle(fontSize: 14,
                                color: _task.isOverdue ? Colors.red : NotionTheme.textPrimary,
                                fontWeight: _task.isOverdue ? FontWeight.w600 : FontWeight.normal)),
                            if (_task.isOverdue) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                child: Text('${DateTime.now().difference(_task.dueDate!).inDays}일 초과',
                                  style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600))),
                            ],
                          ])
                        : const Text('없음', style: TextStyle(color: NotionTheme.textMuted))),
                      _PropertyRow(label: '생성일',
                        child: Text(_fmtDate(_task.createdAt),
                          style: const TextStyle(fontSize: 14, color: NotionTheme.textSecondary))),
                      if (_task.description.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text('설명', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NotionTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: NotionTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: NotionTheme.border),
                          ),
                          child: Text(_task.description,
                            style: const TextStyle(fontSize: 14, color: NotionTheme.textPrimary, height: 1.6)),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),

                  // ── 탭 2: 중간 보고
                  _ReportTab(task: _task),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}';

  Widget _buildAssigneeDisplay(BuildContext context, AppProvider provider) {
    // assigneeIds 기반 다중 담당자 표시
    List<AppUser> assignedUsers = [];
    try {
      final authProv = context.read<AuthProvider>();
      if (_task.assigneeIds.isNotEmpty) {
        assignedUsers = authProv.users
            .where((u) => _task.assigneeIds.contains(u.id))
            .toList();
      }
    } catch (_) {}

    if (assignedUsers.isNotEmpty) {
      // ID로 매칭된 사용자들 표시
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        children: assignedUsers.map((u) {
          final colors = [
            const Color(0xFF2383E2), const Color(0xFF0F7B6C), const Color(0xFF6C5FD4),
            const Color(0xFFEB5757), const Color(0xFFCB912F),
          ];
          final color = colors[u.displayName.isEmpty ? 0 : u.displayName.codeUnitAt(0) % colors.length];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 9, backgroundColor: color,
                child: Text(u.displayName.isNotEmpty ? u.displayName[0] : '?',
                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 5),
              Text(u.displayName, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
            ]),
          );
        }).toList(),
      );
    } else if (_task.assigneeName != null && _task.assigneeName!.isNotEmpty) {
      // 하위 호환: 이름만 있는 경우
      return Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 12,
          backgroundColor: NotionTheme.accentLight,
          child: Text(_task.assigneeName![0],
            style: const TextStyle(fontSize: 11, color: NotionTheme.accent, fontWeight: FontWeight.bold))),
        const SizedBox(width: 8),
        Text(_task.assigneeName!, style: const TextStyle(fontSize: 14, color: NotionTheme.textPrimary)),
      ]);
    }
    return const Text('없음', style: TextStyle(color: NotionTheme.textMuted));
  }
}

// ──────────────────────────────────────────────────────
// 중간 보고 탭
// ──────────────────────────────────────────────────────
class _ReportTab extends StatefulWidget {
  final Task task;
  const _ReportTab({required this.task});

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> {
  final _contentCtrl = TextEditingController();
  final _reporterCtrl = TextEditingController();
  bool _showForm = false;
  TaskReport? _editingReport;

  @override
  void dispose() {
    _contentCtrl.dispose();
    _reporterCtrl.dispose();
    super.dispose();
  }

  void _startEdit(TaskReport report) {
    setState(() {
      _editingReport = report;
      _contentCtrl.text = report.content;
      _reporterCtrl.text = report.reporterName ?? '';
      _showForm = true;
    });
  }

  void _resetForm() {
    setState(() {
      _editingReport = null;
      _contentCtrl.clear();
      _reporterCtrl.clear();
      _showForm = false;
    });
  }

  Future<void> _saveReport(BuildContext context) async {
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보고 내용을 입력해주세요'), backgroundColor: Colors.red),
      );
      return;
    }
    final provider = context.read<AppProvider>();
    if (_editingReport != null) {
      final updated = TaskReport(
        id: _editingReport!.id,
        content: _contentCtrl.text.trim(),
        createdAt: _editingReport!.createdAt,
        reporterName: _reporterCtrl.text.trim().isEmpty ? null : _reporterCtrl.text.trim(),
      );
      await provider.updateReport(widget.task.id, updated);
    } else {
      await provider.addReport(
        widget.task.id,
        content: _contentCtrl.text.trim(),
        reporterName: _reporterCtrl.text.trim().isEmpty ? null : _reporterCtrl.text.trim(),
      );
    }
    _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final freshTask = provider.tasks.firstWhere((t) => t.id == widget.task.id, orElse: () => widget.task);
    final reports = freshTask.reports;

    return Column(
      children: [
        // 보고 작성 폼
        if (_showForm)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NotionTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: NotionTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        _editingReport != null ? '보고 수정' : '중간 보고 작성',
                        style: const TextStyle(fontSize: 12, color: NotionTheme.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _resetForm,
                      child: const Icon(Icons.close, size: 18, color: NotionTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 작성자
                TextField(
                  controller: _reporterCtrl,
                  decoration: InputDecoration(
                    hintText: '작성자 이름 (선택)',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.person_outline, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: NotionTheme.accent)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                // 보고 내용
                TextField(
                  controller: _contentCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: '업무 진행 상황, 결과, 이슈 등을 작성하세요...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: NotionTheme.accent)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _resetForm,
                      child: const Text('취소', style: TextStyle(color: NotionTheme.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _saveReport(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NotionTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        elevation: 0,
                      ),
                      child: Text(_editingReport != null ? '수정 완료' : '보고 등록',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // 보고 작성 버튼 (폼이 닫혀있을 때)
        if (!_showForm)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GestureDetector(
              onTap: () => setState(() => _showForm = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: NotionTheme.accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NotionTheme.accent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 16, color: NotionTheme.accent),
                    SizedBox(width: 6),
                    Text('중간 보고 작성', style: TextStyle(fontSize: 13, color: NotionTheme.accent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),

        // 보고 목록
        Expanded(
          child: reports.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_outlined, size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('아직 보고 내용이 없습니다', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                    const SizedBox(height: 6),
                    Text('위 버튼을 눌러 중간 보고를 작성하세요', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                itemCount: reports.length,
                itemBuilder: (ctx, i) {
                  final report = reports[reports.length - 1 - i]; // 최신순
                  return _ReportItem(
                    report: report,
                    taskId: widget.task.id,
                    onEdit: () => _startEdit(report),
                  );
                },
              ),
        ),
      ],
    );
  }
}

class _ReportItem extends StatefulWidget {
  final TaskReport report;
  final String taskId;
  final VoidCallback onEdit;
  const _ReportItem({required this.report, required this.taskId, required this.onEdit});

  @override
  State<_ReportItem> createState() => _ReportItemState();
}

class _ReportItemState extends State<_ReportItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final r = widget.report;
    final isToday = r.createdAt.year == now.year && r.createdAt.month == now.month && r.createdAt.day == now.day;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _hover ? NotionTheme.accent.withValues(alpha: 0.3) : NotionTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 작성자
                if (r.reporterName != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: 10, backgroundColor: NotionTheme.accentLight,
                      child: Text(r.reporterName![0],
                        style: const TextStyle(fontSize: 9, color: NotionTheme.accent, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 6),
                    Text(r.reporterName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NotionTheme.textPrimary)),
                    const SizedBox(width: 8),
                  ]),
                // 오늘 뱃지
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F7B6C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('오늘', style: TextStyle(fontSize: 10, color: Color(0xFF0F7B6C), fontWeight: FontWeight.w600)),
                  ),
                const Spacer(),
                // 날짜/시간
                Text(_fmtDateTime(r.createdAt),
                  style: const TextStyle(fontSize: 11, color: NotionTheme.textMuted)),
                // 액션 버튼 (hover시 표시)
                if (_hover) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onEdit,
                    child: Icon(Icons.edit_outlined, size: 15, color: NotionTheme.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: Icon(Icons.delete_outline, size: 15, color: Colors.red.shade300),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // 보고 내용
            Text(r.content, style: const TextStyle(fontSize: 13, color: NotionTheme.textPrimary, height: 1.6)),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('보고 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: const Text('이 보고 내용을 삭제하시겠습니까?', style: TextStyle(fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: () {
            context.read<AppProvider>().deleteReport(widget.taskId, widget.report.id);
            Navigator.pop(context);
          },
          child: const Text('삭제', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  String _fmtDateTime(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    }
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }
}

void _openEditForm(BuildContext context, Task task) {
  final appProv  = context.read<AppProvider>();
  final authProv = context.read<AuthProvider>();
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProv),
        ChangeNotifierProvider.value(value: authProv),
      ],
      child: _TaskFormPage(task: task),
    ),
    fullscreenDialog: true,
  ));
}

// ── Status Pill (tapable)
class _StatusPill extends StatelessWidget {
  final Task task;
  final ValueChanged<TaskStatus> onChanged;
  const _StatusPill({required this.task, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStatusMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: task.status.bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(task.status.icon, size: 14, color: task.status.color),
            const SizedBox(width: 5),
            Text(task.status.label, style: TextStyle(fontSize: 13, color: task.status.color, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 14, color: task.status.color),
          ],
        ),
      ),
    );
  }

  void _showStatusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('상태 변경', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...TaskStatus.values.map((s) => ListTile(
              leading: Icon(s.icon, color: s.color),
              title: Text(s.label),
              trailing: task.status == s ? const Icon(Icons.check, color: NotionTheme.accent) : null,
              onTap: () { Navigator.pop(context); onChanged(s); },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: NotionTheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? NotionTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color ?? NotionTheme.textSecondary)),
        ],
      ),
    ),
  );
}

class _PropertyRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _PropertyRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 13, color: NotionTheme.textSecondary))),
        const SizedBox(width: 12),
        child,
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: status.bgColor, borderRadius: BorderRadius.circular(5)),
    child: Text(status.label, style: TextStyle(fontSize: 12, color: status.color, fontWeight: FontWeight.w600)),
  );
}

class _PriorityChip extends StatelessWidget {
  final TaskPriority priority;
  const _PriorityChip({required this.priority});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(priority.icon, size: 14, color: priority.color),
      const SizedBox(width: 4),
      Text(priority.label, style: TextStyle(fontSize: 13, color: priority.color, fontWeight: FontWeight.w500)),
    ],
  );
}

// ── 업무 수정 폼 페이지
class _TaskFormPage extends StatefulWidget {
  final Task? task;
  final String? preselectedDeptId;
  const _TaskFormPage({this.task, this.preselectedDeptId});

  @override
  State<_TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<_TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  String? _deptId;
  TaskStatus _status = TaskStatus.notStarted;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _startDate;
  DateTime? _dueDate;
  // 다중 담당자 - 선택된 사용자 ID 목록
  List<String> _selectedAssigneeIds = [];

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleCtrl   = TextEditingController(text: t?.title ?? '');
    _descCtrl    = TextEditingController(text: t?.description ?? '');
    _deptId      = t?.departmentId ?? widget.preselectedDeptId;
    _status      = t?.status   ?? TaskStatus.notStarted;
    _priority    = t?.priority ?? TaskPriority.medium;
    _startDate   = t?.startDate;
    _dueDate     = t?.dueDate;
    _selectedAssigneeIds = List<String>.from(t?.assigneeIds ?? []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final isEdit = widget.task != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(isEdit ? '업무 수정' : '새 업무',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(isEdit ? '저장' : '추가',
              style: const TextStyle(color: NotionTheme.accent, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: '업무 제목을 입력하세요',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintStyle: TextStyle(color: NotionTheme.textMuted, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: NotionTheme.textPrimary),
              validator: (v) => v == null || v.isEmpty ? '제목을 입력해주세요' : null,
              autofocus: !isEdit,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _FormPropRow(label: '부서', child: _DeptSelector(
              depts: provider.departments,
              selected: _deptId,
              onChanged: (id) => setState(() => _deptId = id),
            )),
            _FormPropRow(label: '상태', child: _DropdownChips<TaskStatus>(
              values: TaskStatus.values,
              selected: _status,
              label: (s) => s.label,
              color: (s) => s.color,
              bgColor: (s) => s.bgColor,
              onChanged: (s) => setState(() => _status = s),
            )),
            _FormPropRow(label: '우선순위', child: _DropdownChips<TaskPriority>(
              values: TaskPriority.values,
              selected: _priority,
              label: (p) => p.label,
              color: (p) => p.color,
              bgColor: (_) => NotionTheme.surface,
              onChanged: (p) => setState(() => _priority = p),
            )),
            // ── 다중 담당자 선택 ──────────────────────────────
            _AssigneeSelectorRow(
              allUsers: _getAvailableUsers(provider),
              selectedIds: _selectedAssigneeIds,
              onChanged: (ids) => setState(() => _selectedAssigneeIds = ids),
            ),
            // 시작일
            _FormPropRow(label: '시작일', child: _DatePickerBtn(
              date: _startDate,
              hint: '일정 시작일',
              color: const Color(0xFF6C5FD4),
              onPick: (d) => setState(() => _startDate = d),
              onClear: () => setState(() => _startDate = null),
            )),
            // 마감일
            _FormPropRow(label: '마감일', child: _DatePickerBtn(
              date: _dueDate,
              hint: '마감 날짜',
              color: NotionTheme.accent,
              onPick: (d) => setState(() => _dueDate = d),
              onClear: () => setState(() => _dueDate = null),
            )),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text('설명', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NotionTheme.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(hintText: '업무 내용을 작성하세요...'),
              maxLines: 6,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// AuthProvider에서 사용자 목록 가져오기
  List<_UserInfo> _getAvailableUsers(AppProvider provider) {
    try {
      final authProv = context.read<AuthProvider>();
      return authProv.users.map((u) => _UserInfo(id: u.id, name: u.displayName)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('부서를 선택해주세요'), backgroundColor: Colors.red),
      );
      return;
    }
    final provider = context.read<AppProvider>();
    // 대표 담당자 이름(assignee_name): 첫 번째 선택자의 displayName
    String? assigneeName;
    if (_selectedAssigneeIds.isNotEmpty) {
      try {
        final users = _getAvailableUsers(provider);
        final first = users.firstWhere(
          (u) => u.id == _selectedAssigneeIds.first,
          orElse: () => _UserInfo(id: '', name: ''),
        );
        if (first.id.isNotEmpty) assigneeName = first.name;
      } catch (_) {}
    }

    if (widget.task != null) {
      final t = widget.task!;
      t.title = _titleCtrl.text.trim();
      t.description = _descCtrl.text.trim();
      t.departmentId = _deptId!;
      t.status = _status;
      t.priority = _priority;
      t.startDate = _startDate;
      t.dueDate = _dueDate;
      t.assigneeName = assigneeName;
      t.assigneeIds = List<String>.from(_selectedAssigneeIds);
      await provider.updateTask(t);
    } else {
      await provider.addTask(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        departmentId: _deptId!,
        status: _status, priority: _priority,
        startDate: _startDate,
        dueDate: _dueDate,
        assigneeName: assigneeName,
        assigneeIds: _selectedAssigneeIds,
      );
    }
    if (mounted) Navigator.pop(context);
  }
}

// ── 사용자 정보 단순 DTO ─────────────────────────────
class _UserInfo {
  final String id;
  final String name;
  const _UserInfo({required this.id, required this.name});
}

// ── 다중 담당자 선택 Row ──────────────────────────────
class _AssigneeSelectorRow extends StatelessWidget {
  final List<_UserInfo> allUsers;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const _AssigneeSelectorRow({
    required this.allUsers,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 72,
            child: Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('담당자', style: TextStyle(fontSize: 13, color: NotionTheme.textSecondary)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 선택된 담당자 칩 목록
                if (selectedIds.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectedIds.map((id) {
                      final user = allUsers.firstWhere(
                        (u) => u.id == id,
                        orElse: () => _UserInfo(id: id, name: id),
                      );
                      return _AssigneeChip(
                        name: user.name,
                        onRemove: () {
                          final newIds = List<String>.from(selectedIds)..remove(id);
                          onChanged(newIds);
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 6),
                // 담당자 추가 버튼
                GestureDetector(
                  onTap: () => _showUserPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: NotionTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: NotionTheme.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_add_outlined, size: 14, color: NotionTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        selectedIds.isEmpty ? '담당자 지정' : '담당자 추가',
                        style: const TextStyle(fontSize: 13, color: NotionTheme.textSecondary),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUserPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) {
        return _UserPickerSheet(
          allUsers: allUsers,
          selectedIds: selectedIds,
          onToggle: (id) {
            final newIds = List<String>.from(selectedIds);
            if (newIds.contains(id)) {
              newIds.remove(id);
            } else {
              newIds.add(id);
            }
            onChanged(newIds);
          },
        );
      },
    );
  }
}

// ── 담당자 칩 위젯 ──────────────────────────────────
class _AssigneeChip extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;
  const _AssigneeChip({required this.name, required this.onRemove});

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF2383E2), const Color(0xFF0F7B6C), const Color(0xFF6C5FD4),
      const Color(0xFFEB5757), const Color(0xFFCB912F), const Color(0xFF4CAF50),
    ];
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: color,
          child: Text(
            name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 5),
        Text(name, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRemove,
          child: Icon(Icons.close, size: 13, color: color.withValues(alpha: 0.7)),
        ),
      ]),
    );
  }
}

// ── 사용자 선택 바텀시트 ────────────────────────────
class _UserPickerSheet extends StatefulWidget {
  final List<_UserInfo> allUsers;
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;
  const _UserPickerSheet({
    required this.allUsers,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  late List<String> _localSelected;

  @override
  void initState() {
    super.initState();
    _localSelected = List<String>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('담당자 선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('여러 명 선택 가능', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const Divider(height: 20),
          if (widget.allUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.person_off_outlined, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('등록된 사용자가 없습니다',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.allUsers.length,
                itemBuilder: (_, i) {
                  final user = widget.allUsers[i];
                  final isSelected = _localSelected.contains(user.id);
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: isSelected
                          ? NotionTheme.accent
                          : NotionTheme.accentLight,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0] : '?',
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white : NotionTheme.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(user.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: NotionTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      )),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: NotionTheme.accent, size: 20)
                        : Icon(Icons.radio_button_unchecked, color: Colors.grey.shade300, size: 20),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _localSelected.remove(user.id);
                        } else {
                          _localSelected.add(user.id);
                        }
                      });
                      widget.onToggle(user.id);
                    },
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: NotionTheme.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(
                _localSelected.isEmpty ? '선택 안 함' : '${_localSelected.length}명 선택 완료',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormPropRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormPropRow({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 13, color: NotionTheme.textSecondary))),
        const SizedBox(width: 12),
        child,
      ],
    ),
  );
}

// ── 날짜 선택 버튼 공용 위젯
class _DatePickerBtn extends StatelessWidget {
  final DateTime? date;
  final String hint;
  final Color color;
  final void Function(DateTime) onPick;
  final VoidCallback onClear;
  const _DatePickerBtn({
    required this.date, required this.hint, required this.color,
    required this.onPick, required this.onClear,
  });

  String _fmt(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasDate ? color.withValues(alpha: 0.1) : NotionTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: hasDate ? color.withValues(alpha: 0.4) : NotionTheme.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined, size: 13,
            color: hasDate ? color : NotionTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            hasDate ? _fmt(date!) : hint,
            style: TextStyle(fontSize: 13,
              color: hasDate ? color : NotionTheme.textSecondary),
          ),
          if (hasDate) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 12, color: color.withValues(alpha: 0.7)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _DeptSelector extends StatelessWidget {
  final List depts;
  final String? selected;
  final ValueChanged<String> onChanged;
  const _DeptSelector({required this.depts, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dept = selected != null
      ? depts.firstWhere((d) => d.id == selected, orElse: () => null)
      : null;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text('부서 선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ...depts.map((d) => ListTile(
                leading: Text(d.emoji, style: const TextStyle(fontSize: 20)),
                title: Text(d.name),
                trailing: selected == d.id ? const Icon(Icons.check, color: NotionTheme.accent) : null,
                onTap: () { onChanged(d.id); Navigator.pop(context); },
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dept != null ? NotionTheme.accentLight : NotionTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: NotionTheme.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(dept?.emoji ?? '📁', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(dept?.name ?? '부서 선택',
            style: TextStyle(fontSize: 13, color: dept != null ? NotionTheme.accent : NotionTheme.textSecondary)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 14, color: NotionTheme.textSecondary),
        ]),
      ),
    );
  }
}

class _DropdownChips<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final Color Function(T) color;
  final Color Function(T) bgColor;
  final ValueChanged<T> onChanged;
  const _DropdownChips({required this.values, required this.selected, required this.label,
    required this.color, required this.bgColor, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: values.map((v) {
      final isSel = v == selected;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSel ? bgColor(v) : NotionTheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isSel ? color(v) : NotionTheme.border, width: isSel ? 1.5 : 1),
          ),
          child: Text(label(v), style: TextStyle(fontSize: 12,
            color: isSel ? color(v) : NotionTheme.textSecondary,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.normal)),
        ),
      );
    }).toList(),
  );
}

// export form page for use across screens
class TaskFormPage extends StatelessWidget {
  final Task? task;
  final String? preselectedDeptId;
  const TaskFormPage({super.key, this.task, this.preselectedDeptId});

  @override
  Widget build(BuildContext context) {
    return _TaskFormPage(task: task, preselectedDeptId: preselectedDeptId);
  }
}
