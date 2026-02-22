import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/notion_theme.dart';
import '../widgets/task_detail_sheet.dart';

class BoardView extends StatelessWidget {
  const BoardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: TaskStatus.values.map((status) {
            final tasks = provider.getTasksByStatus(status);
            final canManage = context.read<AuthProvider>().canManageTask;
            return _BoardColumn(status: status, tasks: tasks, canManage: canManage);
          }).toList(),
        );
      },
    );
  }
}

class _BoardColumn extends StatelessWidget {
  final TaskStatus status;
  final List<Task> tasks;
  final bool canManage;

  const _BoardColumn({required this.status, required this.tasks, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    Color colBg;
    switch (status) {
      case TaskStatus.notStarted: colBg = NotionTheme.colNotStartedBg; break;
      case TaskStatus.inProgress: colBg = NotionTheme.colInProgressBg; break;
      case TaskStatus.done:       colBg = NotionTheme.colDoneBg;       break;
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: colBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 컬럼 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
              child: Row(
                children: [
                  Icon(status.icon, size: 14, color: status.color),
                  const SizedBox(width: 6),
                  Text(status.label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: status.color)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${tasks.length}',
                      style: TextStyle(fontSize: 10, color: status.color, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  // 업무 추가 버튼 (관리자/마스터만)
                  if (canManage)
                    GestureDetector(
                      onTap: () => _addTask(context, provider, status),
                      child: Icon(Icons.add, size: 16, color: status.color.withValues(alpha: 0.7)),
                    ),
                ],
              ),
            ),

            // ── 카드 목록
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: canManage
                  ? DragTarget<String>(
                      onAcceptWithDetails: (details) => provider.updateTaskStatus(details.data, status),
                      builder: (_, candidates, __) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 60,
                        decoration: BoxDecoration(
                          color: candidates.isNotEmpty ? status.color.withValues(alpha: 0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: candidates.isNotEmpty ? status.color.withValues(alpha: 0.3) : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text('여기에 드롭', style: TextStyle(fontSize: 11, color: status.color.withValues(alpha: 0.5))),
                        ),
                      ),
                    )
                  : Container(height: 60),
              )
            else
              ...tasks.map((task) => canManage
                ? _DraggableTaskCard(task: task, columnStatus: status)
                : _TaskCard(task: task)),

            // ── 드롭존 (마지막, 관리자만)
            if (tasks.isNotEmpty && canManage)
              DragTarget<String>(
                onAcceptWithDetails: (details) => provider.updateTaskStatus(details.data, status),
                builder: (_, candidates, __) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: candidates.isNotEmpty ? 50 : 12,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: candidates.isNotEmpty ? status.color.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: candidates.isNotEmpty ? status.color.withValues(alpha: 0.3) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: candidates.isNotEmpty
                    ? Center(child: Text('여기에 드롭', style: TextStyle(fontSize: 11, color: status.color.withValues(alpha: 0.6))))
                    : null,
                ),
              )
            else if (tasks.isNotEmpty)
              const SizedBox(height: 12),

            // ── 하단 추가 버튼 (관리자/마스터만)
            if (canManage)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: GestureDetector(
                  onTap: () => _addTask(context, provider, status),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 14, color: NotionTheme.textSecondary),
                        const SizedBox(width: 4),
                        const Text('새 업무', style: TextStyle(fontSize: 12, color: NotionTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _addTask(BuildContext context, AppProvider provider, TaskStatus status) {
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

class _DraggableTaskCard extends StatelessWidget {
  final Task task;
  final TaskStatus columnStatus;

  const _DraggableTaskCard({required this.task, required this.columnStatus});

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: task.id,
      feedback: Material(
        borderRadius: BorderRadius.circular(8),
        elevation: 6,
        child: SizedBox(
          width: 200,
          child: _TaskCard(task: task, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _TaskCard(task: task)),
      child: _TaskCard(task: task),
    );
  }
}

class _TaskCard extends StatefulWidget {
  final Task task;
  final bool isDragging;
  const _TaskCard({required this.task, this.isDragging = false});

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _hover = false;
  bool _hiding = false;

  Future<void> _hideTask(BuildContext context) async {
    final provider = context.read<AppProvider>();
    setState(() => _hiding = true);
    try {
      await provider.hideTask(widget.task.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('완료 업무를 보관함으로 이동했습니다'),
            action: SnackBarAction(
              label: '취소',
              onPressed: () async {
                await provider.unhideTask(widget.task.id);
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
        setState(() => _hiding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final dept = provider.getDeptById(widget.task.departmentId);
    final canManage = context.read<AuthProvider>().canManageTask;
    final isDone = widget.task.status == TaskStatus.done;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => showTaskDetail(context, widget.task),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hover ? NotionTheme.accent.withValues(alpha: 0.4) : NotionTheme.border),
            boxShadow: _hover ? [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))
            ] : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 2, offset: const Offset(0, 1))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 우선순위 + 제목 + 숨기기 버튼
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(widget.task.priority.icon, size: 12, color: widget.task.priority.color),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      widget.task.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDone
                          ? NotionTheme.textSecondary : NotionTheme.textPrimary,
                        decoration: isDone
                          ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  // 완료 항목에만 숨기기 버튼 표시 (관리자/마스터, 호버 시)
                  if (isDone && canManage && _hover && !_hiding)
                    GestureDetector(
                      onTap: () => _hideTask(context),
                      child: Tooltip(
                        message: '보관함으로 이동 (보드에서 숨김)',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.archive_outlined, size: 11, color: Color(0xFF787774)),
                              SizedBox(width: 3),
                              Text('숨기기', style: TextStyle(fontSize: 10, color: Color(0xFF787774))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_hiding)
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                ],
              ),

              // 설명
              if (widget.task.description.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  widget.task.description,
                  style: const TextStyle(fontSize: 11, color: NotionTheme.textSecondary, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 10),

              // 하단: 부서 태그 + 마감일 + 담당자
              Row(
                children: [
                  // 부서 태그
                  if (dept != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: NotionTheme.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: NotionTheme.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(dept.emoji, style: const TextStyle(fontSize: 10)),
                        const SizedBox(width: 3),
                        Text(dept.name, style: const TextStyle(fontSize: 10, color: NotionTheme.textSecondary)),
                      ]),
                    ),
                  const Spacer(),
                  // 마감일
                  if (widget.task.dueDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.task.isOverdue ? Colors.red.shade50 : NotionTheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.calendar_today, size: 9,
                          color: widget.task.isOverdue ? Colors.red : NotionTheme.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.task.dueDate!.month}/${widget.task.dueDate!.day}',
                          style: TextStyle(fontSize: 10,
                            color: widget.task.isOverdue ? Colors.red : NotionTheme.textMuted,
                            fontWeight: widget.task.isOverdue ? FontWeight.bold : FontWeight.normal),
                        ),
                      ]),
                    ),
                  if (widget.task.assigneeNames.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _MultiAssigneeAvatars(
                      names: widget.task.assigneeNames,
                      maxShow: 3,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 다중 담당자 아바타 (겹쳐 표시) ─────────────────────
class _MultiAssigneeAvatars extends StatelessWidget {
  final List<String> names;
  final int maxShow;
  const _MultiAssigneeAvatars({required this.names, this.maxShow = 3});

  static const _colors = [
    Color(0xFF2383E2), Color(0xFF0F7B6C), Color(0xFF6C5FD4),
    Color(0xFFEB5757), Color(0xFFCB912F), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFF00796B),
  ];

  Color _avatarColor(String name) =>
      name.isEmpty ? _colors[0] : _colors[name.codeUnitAt(0) % _colors.length];

  @override
  Widget build(BuildContext context) {
    final showCount = names.length > maxShow ? maxShow : names.length;
    final extra = names.length - maxShow;

    return SizedBox(
      width: showCount * 14.0 + (extra > 0 ? 18 : 0),
      height: 20,
      child: Stack(
        children: [
          for (int i = 0; i < showCount; i++)
            Positioned(
              left: i * 14.0,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: _avatarColor(names[i]),
                child: Text(
                  names[i].isNotEmpty ? names[i][0] : '?',
                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: maxShow * 14.0,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: Colors.grey.shade400,
                child: Text(
                  '+$extra',
                  style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
