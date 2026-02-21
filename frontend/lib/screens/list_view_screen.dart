import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/notion_theme.dart';
import '../widgets/task_detail_sheet.dart';

class ListViewScreen extends StatelessWidget {
  const ListViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final tasks = provider.getAllFilteredTasks();

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('📋', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('업무가 없습니다', style: TextStyle(color: NotionTheme.textSecondary, fontSize: 16)),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _addTask(context, provider),
                  icon: const Icon(Icons.add),
                  label: const Text('새 업무 추가'),
                  style: TextButton.styleFrom(foregroundColor: NotionTheme.accent),
                ),
              ],
            ),
          );
        }

        // 상태별 그룹핑
        return ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: TaskStatus.values.map((status) {
            final group = tasks.where((t) => t.status == status).toList();
            if (group.isEmpty) return const SizedBox.shrink();
            return _StatusGroup(status: status, tasks: group);
          }).toList(),
        );
      },
    );
  }

  void _addTask(BuildContext context, AppProvider provider) {
    final deptId = provider.selectedDeptId ?? (provider.departments.isNotEmpty ? provider.departments.first.id : null);
    if (deptId == null) return;
    Navigator.push(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TaskFormPage(preselectedDeptId: deptId),
    ));
  }
}

class _StatusGroup extends StatefulWidget {
  final TaskStatus status;
  final List<Task> tasks;
  const _StatusGroup({required this.status, required this.tasks});

  @override
  State<_StatusGroup> createState() => _StatusGroupState();
}

class _StatusGroupState extends State<_StatusGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 그룹 헤더
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down, size: 16, color: widget.status.color),
                ),
                const SizedBox(width: 8),
                Icon(widget.status.icon, size: 14, color: widget.status.color),
                const SizedBox(width: 6),
                Text(widget.status.label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.status.color)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.status.bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${widget.tasks.length}',
                    style: TextStyle(fontSize: 10, color: widget.status.color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // 업무 행
        if (_expanded)
          ...widget.tasks.map((task) => _ListRow(task: task)),

        if (_expanded) const SizedBox(height: 8),
      ],
    );
  }
}

class _ListRow extends StatefulWidget {
  final Task task;
  const _ListRow({required this.task});

  @override
  State<_ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<_ListRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final dept = provider.getDeptById(widget.task.departmentId);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => showTaskDetail(context, widget.task),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _hover ? const Color(0xFFF7F7F5) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              // 상태 아이콘 (탭으로 변경)
              GestureDetector(
                onTap: () => _cycleStatus(context, provider),
                child: Icon(widget.task.status.icon, size: 18, color: widget.task.status.color),
              ),
              const SizedBox(width: 12),

              // 제목
              Expanded(
                flex: 3,
                child: Text(
                  widget.task.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.task.status == TaskStatus.done
                      ? NotionTheme.textSecondary : NotionTheme.textPrimary,
                    decoration: widget.task.status == TaskStatus.done
                      ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 부서
              if (dept != null)
                Expanded(
                  flex: 2,
                  child: Row(children: [
                    Text(dept.emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Flexible(child: Text(dept.name,
                      style: const TextStyle(fontSize: 12, color: NotionTheme.textSecondary),
                      overflow: TextOverflow.ellipsis)),
                  ]),
                ),

              // 우선순위
              SizedBox(
                width: 52,
                child: Row(children: [
                  Icon(widget.task.priority.icon, size: 12, color: widget.task.priority.color),
                  const SizedBox(width: 3),
                  Text(widget.task.priority.label,
                    style: TextStyle(fontSize: 11, color: widget.task.priority.color)),
                ]),
              ),

              // 마감일
              SizedBox(
                width: 56,
                child: widget.task.dueDate != null
                  ? Text(
                      '${widget.task.dueDate!.month}/${widget.task.dueDate!.day}',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.task.isOverdue ? Colors.red : NotionTheme.textSecondary,
                        fontWeight: widget.task.isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    )
                  : const SizedBox.shrink(),
              ),

              // 담당자
              widget.task.assigneeName != null
                ? CircleAvatar(
                    radius: 11,
                    backgroundColor: NotionTheme.accentLight,
                    child: Text(widget.task.assigneeName![0],
                      style: const TextStyle(fontSize: 10, color: NotionTheme.accent, fontWeight: FontWeight.bold)),
                  )
                : const SizedBox(width: 22),
            ],
          ),
        ),
      ),
    );
  }

  void _cycleStatus(BuildContext context, AppProvider provider) {
    final next = TaskStatus.values[(widget.task.status.index + 1) % TaskStatus.values.length];
    provider.updateTaskStatus(widget.task.id, next);
  }
}
