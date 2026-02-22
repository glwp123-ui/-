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
    if (_task.assigneeNames.isEmpty) {
      return const Text('없음', style: TextStyle(color: NotionTheme.textMuted));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: _task.assigneeNames.map((name) {
        const colors = [
          Color(0xFF2383E2), Color(0xFF0F7B6C), Color(0xFF6C5FD4),
          Color(0xFFEB5757), Color(0xFFCB912F), Color(0xFF4CAF50),
          Color(0xFF9C27B0), Color(0xFF00796B),
        ];
        final color = name.isEmpty ? colors[0] : colors[name.codeUnitAt(0) % colors.length];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(radius: 9, backgroundColor: color,
              child: Text(name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(width: 5),
            Text(name, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
          ]),
        );
      }).toList(),
    );
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
  final DateTime? preselectedDueDate;
  const _TaskFormPage({
    this.task,
    this.preselectedDeptId,
    this.preselectedDueDate,
  });

  @override
  State<_TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<_TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  List<String> _deptIds = [];   // 다중 부서
  TaskStatus _status = TaskStatus.notStarted;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _startDate;
  DateTime? _dueDate;
  List<String> _selectedNames = [];

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _descCtrl  = TextEditingController(text: t?.description ?? '');
    _deptIds   = t != null
        ? List<String>.from(t.departmentIds)
        : (widget.preselectedDeptId != null ? [widget.preselectedDeptId!] : []);
    _status    = t?.status   ?? TaskStatus.notStarted;
    _priority  = t?.priority ?? TaskPriority.medium;
    _startDate = t?.startDate;
    _dueDate   = t?.dueDate ?? widget.preselectedDueDate;
    _selectedNames = List<String>.from(t?.assigneeNames ?? []);
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
            _MultiDeptSelector(
              allDepts: provider.departments,
              selectedIds: _deptIds,
              onChanged: (ids) => setState(() => _deptIds = ids),
            ),
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

  List<AppUser> _getAllUsers() {
    try {
      return context.read<AuthProvider>().users
          .where((u) => u.role != UserRole.master &&
                        u.departmentId != null &&
                        u.departmentId!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('부서를 선택해주세요'), backgroundColor: Colors.red),
      );
      return;
    }
    final provider = context.read<AppProvider>();
    // 첫 번째 부서 ID를 기본 departmentId로 사용 (백엔드 호환)
    final primaryDeptId = _deptIds.first;
    if (widget.task != null) {
      final t = widget.task!;
      t.title        = _titleCtrl.text.trim();
      t.description  = _descCtrl.text.trim();
      t.departmentId = primaryDeptId;
      t.departmentIds = List<String>.from(_deptIds);
      t.status       = _status;
      t.priority     = _priority;
      t.startDate    = _startDate;
      t.dueDate      = _dueDate;
      t.assigneeNames = List<String>.from(_selectedNames);
      await provider.updateTask(t);
    } else {
      await provider.addTask(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        departmentId: primaryDeptId,
        departmentIds: _deptIds,
        status: _status, priority: _priority,
        startDate: _startDate,
        dueDate: _dueDate,
        assigneeNames: _selectedNames,
      );
    }
    if (mounted) Navigator.pop(context);
  }
}

// ── 부서별 담당자 선택 Row (폼에서 사용) ──────────────
class _AssigneeByDeptRow extends StatelessWidget {
  final List<Department> allDepts;
  final List<AppUser> allUsers;
  final List<String> selectedNames;
  final ValueChanged<List<String>> onChanged;

  const _AssigneeByDeptRow({
    required this.allDepts,
    required this.allUsers,
    required this.selectedNames,
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
                // 선택된 담당자 이름 칩들
                if (selectedNames.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectedNames.map((name) => _NameChip(
                      name: name,
                      onRemove: () {
                        final next = List<String>.from(selectedNames)..remove(name);
                        onChanged(next);
                      },
                    )).toList(),
                  ),
                const SizedBox(height: 6),
                // 담당자 선택 버튼
                GestureDetector(
                  onTap: () => _openPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: NotionTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: NotionTheme.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.group_add_outlined, size: 15, color: NotionTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        selectedNames.isEmpty ? '담당자 지정' : '담당자 변경',
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

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AssigneeByDeptSheet(
        allDepts: allDepts,
        allUsers: allUsers,
        selectedNames: selectedNames,
        onConfirm: onChanged,
      ),
    );
  }
}

// ── 이름 칩 (선택된 담당자 표시 + 제거) ─────────────
class _NameChip extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;
  const _NameChip({required this.name, required this.onRemove});

  static const _colors = [
    Color(0xFF2383E2), Color(0xFF0F7B6C), Color(0xFF6C5FD4),
    Color(0xFFEB5757), Color(0xFFCB912F), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFF00796B),
  ];

  Color get _color => name.isEmpty ? _colors[0] : _colors[name.codeUnitAt(0) % _colors.length];

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 10, backgroundColor: c,
          child: Text(name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 5),
        Text(name, style: TextStyle(fontSize: 13, color: c, fontWeight: FontWeight.w500)),
        const SizedBox(width: 3),
        GestureDetector(
          onTap: onRemove,
          child: Icon(Icons.close, size: 13, color: c.withValues(alpha: 0.6)),
        ),
      ]),
    );
  }
}

// ── 부서별 담당자 선택 바텀시트 ──────────────────────
class _AssigneeByDeptSheet extends StatefulWidget {
  final List<Department> allDepts;
  final List<AppUser> allUsers;
  final List<String> selectedNames;
  final ValueChanged<List<String>> onConfirm;

  const _AssigneeByDeptSheet({
    required this.allDepts,
    required this.allUsers,
    required this.selectedNames,
    required this.onConfirm,
  });

  @override
  State<_AssigneeByDeptSheet> createState() => _AssigneeByDeptSheetState();
}

class _AssigneeByDeptSheetState extends State<_AssigneeByDeptSheet> {
  late List<String> _selected; // 선택된 이름 목록 (중복 허용)

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.selectedNames);
  }

  // 추가 (중복 허용)
  void _add(String name) {
    setState(() => _selected.add(name));
  }

  // 마지막으로 추가된 항목 하나 제거
  void _remove(String name) {
    setState(() {
      final idx = _selected.lastIndexOf(name);
      if (idx != -1) _selected.removeAt(idx);
    });
  }

  bool _contains(String name) => _selected.contains(name);

  int _countOf(String name) => _selected.where((e) => e == name).length;

  @override
  Widget build(BuildContext context) {
    // 부서별로 사용자 그룹화
    final Map<String, List<AppUser>> byDept = {};
    for (final u in widget.allUsers) {
      if (!u.isActive) continue;
      if (u.departmentId != null && u.departmentId!.isNotEmpty) {
        byDept.putIfAbsent(u.departmentId!, () => []).add(u);
      }
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          // 핸들
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ),
          // 타이틀
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('담당자 선택', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_selected.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: NotionTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${_selected.length}개 선택',
                      style: const TextStyle(fontSize: 12, color: NotionTheme.accent, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 4, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('부서 또는 개인을 중복 선택 가능',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ),
          ),
          const Divider(height: 1),
          // 목록
          Expanded(
            child: widget.allDepts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('등록된 부서가 없습니다',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      for (final dept in widget.allDepts) ...[
                        // ── 부서 행 (부서명 자체 선택) ──
                        _DeptSelectTile(
                          dept: dept,
                          count: _countOf(dept.name),
                          onAdd: () => _add(dept.name),
                          onRemove: () => _remove(dept.name),
                        ),
                        // ── 소속 인원 ──
                        if (byDept.containsKey(dept.id))
                          for (final u in byDept[dept.id]!)
                            _PersonTile(
                              name: u.displayName,
                              count: _countOf(u.displayName),
                              onAdd: () => _add(u.displayName),
                              onRemove: () => _remove(u.displayName),
                            ),
                      ],
                    ],
                  ),
          ),
          // 확인 버튼
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ElevatedButton(
                onPressed: () {
                  widget.onConfirm(_selected);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NotionTheme.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(
                  _selected.isEmpty ? '담당자 없이 저장' : '${_selected.length}개 선택 완료',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 부서 선택 타일 (부서명 자체를 담당자로 추가/제거) ──
class _DeptSelectTile extends StatelessWidget {
  final Department dept;
  final int count;       // 현재 선택된 횟수
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _DeptSelectTile({
    required this.dept, required this.count,
    required this.onAdd, required this.onRemove,
  });

  static const _colors = [
    Color(0xFF2383E2), Color(0xFF0F7B6C), Color(0xFF6C5FD4),
    Color(0xFFEB5757), Color(0xFFCB912F), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFF00796B),
  ];
  Color get _color => dept.name.isEmpty ? _colors[0]
      : _colors[dept.name.codeUnitAt(0) % _colors.length];

  @override
  Widget build(BuildContext context) {
    final c = _color;
    final selected = count > 0;
    return Container(
      color: selected ? c.withValues(alpha: 0.06) : null,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(dept.emoji, style: const TextStyle(fontSize: 16)),
          ),
        ),
        title: Text(
          dept.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? c : const Color(0xFF1A1A1A),
          ),
        ),
        subtitle: Text('부서 전체', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.remove, size: 16, color: Colors.black54),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text('$count',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c)),
                ),
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add, size: 16, color: c),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 개인 선택 타일 (인원 이름 추가/제거) ──────────────
class _PersonTile extends StatelessWidget {
  final String name;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _PersonTile({
    required this.name, required this.count,
    required this.onAdd, required this.onRemove,
  });

  static const _colors = [
    Color(0xFF2383E2), Color(0xFF0F7B6C), Color(0xFF6C5FD4),
    Color(0xFFEB5757), Color(0xFFCB912F), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFF00796B),
  ];
  Color get _color => name.isEmpty ? _colors[0]
      : _colors[name.codeUnitAt(0) % _colors.length];

  @override
  Widget build(BuildContext context) {
    final c = _color;
    final selected = count > 0;
    return Container(
      color: selected ? c.withValues(alpha: 0.04) : null,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 52, right: 20),
        leading: CircleAvatar(
          radius: 14, backgroundColor: selected ? c : Colors.grey.shade300,
          child: Text(
            name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontSize: 13,
            color: selected ? c : const Color(0xFF444444),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.remove, size: 14, color: Colors.black54),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text('$count',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
                ),
              ),
              const SizedBox(width: 6),
            ],
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add, size: 14, color: c),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 부서 헤더 (레거시 - 미사용) ──────────────────────
class _DeptHeader extends StatelessWidget {
  final String emoji;
  final String name;
  const _DeptHeader({required this.emoji, required this.name});

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF7F6F3),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 6),
      Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NotionTheme.textSecondary)),
    ]),
  );
}

// ── 사용자 타일 ────────────────────────────────────
class _UserTile extends StatelessWidget {
  final AppUser user;
  final bool isSelected;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.isSelected, required this.onTap});

  static const _colors = [
    Color(0xFF2383E2), Color(0xFF0F7B6C), Color(0xFF6C5FD4),
    Color(0xFFEB5757), Color(0xFFCB912F), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFF00796B),
  ];

  Color get _avatarColor {
    final n = user.displayName;
    return n.isEmpty ? _colors[0] : _colors[n.codeUnitAt(0) % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final c = _avatarColor;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? NotionTheme.accent.withValues(alpha: 0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isSelected ? c : c.withValues(alpha: 0.15),
              child: Text(
                user.displayName.isNotEmpty ? user.displayName[0] : '?',
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : c,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: NotionTheme.textPrimary,
                    )),
                  Text(user.username,
                    style: const TextStyle(fontSize: 11, color: NotionTheme.textMuted)),
                ],
              ),
            ),
            isSelected
                ? const Icon(Icons.check_circle_rounded, color: NotionTheme.accent, size: 22)
                : Icon(Icons.radio_button_unchecked, color: Colors.grey.shade300, size: 22),
          ],
        ),
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

// ── 다중 부서 선택 Row (폼에서 사용) ──────────────────
class _MultiDeptSelector extends StatelessWidget {
  final List<Department> allDepts;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const _MultiDeptSelector({
    required this.allDepts,
    required this.selectedIds,
    required this.onChanged,
  });

  static const _colors = [
    Color(0xFF2383E2), Color(0xFF0F7B6C), Color(0xFF6C5FD4),
    Color(0xFFEB5757), Color(0xFFCB912F), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFF00796B),
  ];
  Color _color(String name) =>
      name.isEmpty ? _colors[0] : _colors[name.codeUnitAt(0) % _colors.length];

  Department? _deptById(String id) {
    try { return allDepts.firstWhere((d) => d.id == id); } catch (_) { return null; }
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MultiDeptPickerSheet(
        allDepts: allDepts,
        selectedIds: selectedIds,
        onConfirm: onChanged,
      ),
    );
  }

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
              child: Text('부서', style: TextStyle(fontSize: 13, color: NotionTheme.textSecondary)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 선택된 부서 칩
                if (selectedIds.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectedIds.map((id) {
                      final dept = _deptById(id);
                      final name = dept?.name ?? id;
                      final emoji = dept?.emoji ?? '📁';
                      final c = _color(name);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.withValues(alpha: 0.35)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(emoji, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(name, style: TextStyle(fontSize: 13, color: c, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 3),
                          GestureDetector(
                            onTap: () {
                              final next = List<String>.from(selectedIds);
                              final idx = next.lastIndexOf(id);
                              if (idx != -1) next.removeAt(idx);
                              onChanged(next);
                            },
                            child: Icon(Icons.close, size: 13, color: c.withValues(alpha: 0.6)),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _openPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: NotionTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: NotionTheme.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.business_outlined, size: 15, color: NotionTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        selectedIds.isEmpty ? '부서 선택' : '부서 추가/변경',
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
}

// ── 다중 부서 선택 바텀시트 ──────────────────────────
class _MultiDeptPickerSheet extends StatefulWidget {
  final List<Department> allDepts;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onConfirm;

  const _MultiDeptPickerSheet({
    required this.allDepts,
    required this.selectedIds,
    required this.onConfirm,
  });

  @override
  State<_MultiDeptPickerSheet> createState() => _MultiDeptPickerSheetState();
}

class _MultiDeptPickerSheetState extends State<_MultiDeptPickerSheet> {
  late List<String> _selected;

  // 전체 부서를 나타내는 가상 ID
  static const _allId = '__ALL__';

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.selectedIds);
  }

  bool get _isAllSelected => _selected.length == 1 && _selected.first == _allId;

  void _add(String id) => setState(() => _selected.add(id));
  void _removeLast(String id) {
    setState(() {
      final idx = _selected.lastIndexOf(id);
      if (idx != -1) _selected.removeAt(idx);
    });
  }
  int _countOf(String id) => _selected.where((e) => e == id).length;

  void _selectAll() {
    setState(() {
      _selected = [_allId];
    });
  }

  static const _colors = [
    Color(0xFF2383E2), Color(0xFF0F7B6C), Color(0xFF6C5FD4),
    Color(0xFFEB5757), Color(0xFFCB912F), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFF00796B),
  ];
  Color _color(String name) =>
      name.isEmpty ? _colors[0] : _colors[name.codeUnitAt(0) % _colors.length];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('부서 선택', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_selected.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: NotionTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isAllSelected ? '전체 선택됨' : '${_selected.length}개 선택',
                      style: const TextStyle(fontSize: 12, color: NotionTheme.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 4, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('부서를 중복 선택할 수 있습니다',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                // ── 전체 부서 항목
                _DeptPickerTile(
                  emoji: '🏢',
                  name: '전체',
                  color: const Color(0xFF2383E2),
                  count: _isAllSelected ? 1 : 0,
                  onAdd: _selectAll,
                  onRemove: () => setState(() => _selected.remove(_allId)),
                  subtitle: '모든 부서 포함',
                ),
                const Divider(height: 1, indent: 20),
                // ── 개별 부서 항목들
                for (final dept in widget.allDepts)
                  _DeptPickerTile(
                    emoji: dept.emoji,
                    name: dept.name,
                    color: _color(dept.name),
                    count: _countOf(dept.id),
                    onAdd: () {
                      // 전체 선택 해제 후 개별 추가
                      if (_isAllSelected) setState(() => _selected.clear());
                      _add(dept.id);
                    },
                    onRemove: () => _removeLast(dept.id),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ElevatedButton(
                onPressed: () {
                  widget.onConfirm(_selected);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NotionTheme.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(
                  _selected.isEmpty ? '선택 없이 저장' :
                  _isAllSelected ? '전체 부서로 저장' : '${_selected.length}개 선택 완료',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 부서 피커 타일 ──────────────────────────────────
class _DeptPickerTile extends StatelessWidget {
  final String emoji;
  final String name;
  final Color color;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final String? subtitle;

  const _DeptPickerTile({
    required this.emoji, required this.name, required this.color,
    required this.count, required this.onAdd, required this.onRemove,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final selected = count > 0;
    return Container(
      color: selected ? color.withValues(alpha: 0.05) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
        ),
        title: Text(name, style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? color : const Color(0xFF1A1A1A),
        )),
        subtitle: subtitle != null
            ? Text(subtitle!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove, size: 16, color: Colors.black54),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text('$count',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color))),
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add, size: 16, color: color),
              ),
            ),
          ],
        ),
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

// ── 달력에서 신규 업무 폼 바텀시트 열기 (날짜 미리 세팅)
void showNewTaskForm(BuildContext context, {DateTime? preselectedDueDate}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: context.read<AppProvider>()),
        ChangeNotifierProvider.value(value: context.read<AuthProvider>()),
      ],
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        builder: (_, sc) => _TaskFormPage(
          preselectedDueDate: preselectedDueDate,
        ),
      ),
    ),
  );
}

// export form page for use across screens
class TaskFormPage extends StatelessWidget {
  final Task? task;
  final String? preselectedDeptId;
  final DateTime? preselectedDueDate;
  const TaskFormPage({
    super.key,
    this.task,
    this.preselectedDeptId,
    this.preselectedDueDate,
  });

  @override
  Widget build(BuildContext context) {
    return _TaskFormPage(
      task: task,
      preselectedDeptId: preselectedDeptId,
      preselectedDueDate: preselectedDueDate,
    );
  }
}
