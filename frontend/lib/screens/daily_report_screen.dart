import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/notion_theme.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _reportData = [];
  bool _loadingReport = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReport());
  }

  Future<void> _loadReport() async {
    if (!mounted) return;
    setState(() => _loadingReport = true);
    try {
      final provider = context.read<AppProvider>();
      final data = await provider.getDailyReportDataAsync(_selectedDate);
      if (mounted) setState(() { _reportData = data; _loadingReport = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>(); // rebuild trigger
    final reportData = _reportData;
    final isToday = _isToday(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: NotionTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📋 일일 업무 보고',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NotionTheme.textPrimary)),
            Text('원장님 보고용', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        actions: [
          // 날짜 선택 버튼
          GestureDetector(
            onTap: () => _selectDate(context),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: NotionTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NotionTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: NotionTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(_fmtDateLabel(_selectedDate),
                    style: const TextStyle(fontSize: 12, color: NotionTheme.textPrimary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          // 복사 버튼
          IconButton(
            onPressed: reportData.isEmpty ? null : () => _copyReport(context, reportData),
            icon: const Icon(Icons.copy_outlined),
            color: NotionTheme.textSecondary,
            tooltip: '보고문 복사',
          ),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: Column(
        children: [
          // 헤더 배너
          _HeaderBanner(date: _selectedDate, isToday: isToday, reportData: reportData),

          // 본문
          Expanded(
            child: _loadingReport
              ? const Center(child: CircularProgressIndicator())
              : reportData.isEmpty
                ? _EmptyState(date: _selectedDate, isToday: isToday)
                : _ReportBody(reportData: reportData, date: _selectedDate),
          ),
        ],
      ),

      // 공유/복사 FAB
      floatingActionButton: reportData.isEmpty ? null : FloatingActionButton.extended(
        onPressed: () => _copyReport(context, reportData),
        backgroundColor: NotionTheme.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.copy, size: 18),
        label: const Text('보고문 복사', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _fmtDateLabel(DateTime d) {
    if (_isToday(d)) return '오늘';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day - 1) return '어제';
    return '${d.month}월 ${d.day}일';
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: '보고 날짜 선택',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadReport();
    }
  }

  void _copyReport(BuildContext context, List<Map<String, dynamic>> data) {
    final buf = StringBuffer();
    final now = _selectedDate;
    buf.writeln('📋 일일 업무 보고');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('📅 ${now.year}년 ${now.month}월 ${now.day}일');
    buf.writeln('');

    int totalDone = 0;
    int totalInProgress = 0;

    for (final item in data) {
      final dept = item['dept'] as Department;
      final tasks = item['tasks'] as List<Task>;
      final done = tasks.where((t) => t.status == TaskStatus.done).toList();
      final inProgress = tasks.where((t) => t.status == TaskStatus.inProgress).toList();
      totalDone += done.length;
      totalInProgress += inProgress.length;

      buf.writeln('${dept.emoji} ${dept.name}');
      if (dept.managerName != null) buf.writeln('   담당: ${dept.managerName}');
      buf.writeln('');

      if (done.isNotEmpty) {
        buf.writeln('  ✅ 완료 업무');
        for (final t in done) {
          buf.writeln('    • ${t.title}');
          if (t.assigneeName != null) buf.writeln('      담당자: ${t.assigneeName}');
          // 오늘 보고 내용 추가
          final todayReports = t.reports.where((r) {
            return r.createdAt.year == now.year && r.createdAt.month == now.month && r.createdAt.day == now.day;
          }).toList();
          for (final r in todayReports) {
            buf.writeln('      📝 ${r.content}');
          }
        }
        buf.writeln('');
      }

      if (inProgress.isNotEmpty) {
        buf.writeln('  🔄 진행 중 (보고됨)');
        for (final t in inProgress) {
          final rpts = t.reports.where((r) {
            return r.createdAt.year == now.year && r.createdAt.month == now.month && r.createdAt.day == now.day;
          }).toList();
          if (rpts.isEmpty) continue;
          buf.writeln('    • ${t.title}');
          if (t.assigneeName != null) buf.writeln('      담당자: ${t.assigneeName}');
          for (final r in rpts) {
            buf.writeln('      📝 ${r.content}');
          }
        }
        buf.writeln('');
      }
    }

    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('✅ 완료: $totalDone건  🔄 진행보고: $totalInProgress건');

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('보고문이 클립보드에 복사되었습니다!'),
          ],
        ),
        backgroundColor: const Color(0xFF0F7B6C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── 헤더 배너
class _HeaderBanner extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final List<Map<String, dynamic>> reportData;

  const _HeaderBanner({required this.date, required this.isToday, required this.reportData});

  @override
  Widget build(BuildContext context) {
    int totalDone = 0;
    int totalReports = 0;
    int totalDepts = reportData.length;

    for (final item in reportData) {
      final tasks = item['tasks'] as List<Task>;
      totalDone += tasks.where((t) => t.status == TaskStatus.done).length;
      for (final t in tasks) {
        totalReports += t.reports.where((r) {
          return r.createdAt.year == date.year && r.createdAt.month == date.month && r.createdAt.day == date.day;
        }).length;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A73E8).withValues(alpha: 0.08),
            const Color(0xFF0F7B6C).withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${date.year}년 ${date.month}월 ${date.day}일',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: NotionTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isToday ? '오늘의 업무 현황' : '${date.month}/${date.day} 업무 현황',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F7B6C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 7, color: Colors.white),
                      SizedBox(width: 5),
                      Text('오늘', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatCard(value: '$totalDepts', label: '보고 부서', icon: Icons.business, color: const Color(0xFF1A73E8)),
              const SizedBox(width: 10),
              _StatCard(value: '$totalDone', label: '완료 업무', icon: Icons.check_circle_outline, color: const Color(0xFF0F7B6C)),
              const SizedBox(width: 10),
              _StatCard(value: '$totalReports', label: '중간 보고', icon: Icons.assignment_outlined, color: const Color(0xFFCB912F)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    ),
  );
}

// ── 빈 상태
class _EmptyState extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  const _EmptyState({required this.date, required this.isToday});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          isToday ? '오늘 완료되거나 보고된 업무가 없습니다' : '${date.month}/${date.day}에 완료되거나 보고된 업무가 없습니다',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isToday
            ? '업무를 완료하거나 중간 보고를 작성하면\n이곳에 모아볼 수 있습니다'
            : '해당 날짜에 작성된 중간 보고나 완료된 업무가 없습니다',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ── 보고 본문
class _ReportBody extends StatelessWidget {
  final List<Map<String, dynamic>> reportData;
  final DateTime date;
  const _ReportBody({required this.reportData, required this.date});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reportData.length,
      itemBuilder: (ctx, i) {
        final item = reportData[i];
        final dept = item['dept'] as Department;
        final tasks = item['tasks'] as List<Task>;
        return _DeptReportSection(dept: dept, tasks: tasks, date: date);
      },
    );
  }
}

// ── 부서별 보고 섹션
class _DeptReportSection extends StatefulWidget {
  final Department dept;
  final List<Task> tasks;
  final DateTime date;
  const _DeptReportSection({required this.dept, required this.tasks, required this.date});

  @override
  State<_DeptReportSection> createState() => _DeptReportSectionState();
}

class _DeptReportSectionState extends State<_DeptReportSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final doneTasks = widget.tasks.where((t) => t.status == TaskStatus.done).toList();
    final progressTasks = widget.tasks.where((t) {
      return t.status == TaskStatus.inProgress && t.reports.any((r) {
        return r.createdAt.year == widget.date.year &&
               r.createdAt.month == widget.date.month &&
               r.createdAt.day == widget.date.day;
      });
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // 부서 헤더
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F6),
                borderRadius: _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(widget.dept.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.dept.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: NotionTheme.textPrimary)),
                        if (widget.dept.managerName != null)
                          Text('담당: ${widget.dept.managerName}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  // 완료/진행 뱃지
                  if (doneTasks.isNotEmpty)
                    _Badge(label: '완료 ${doneTasks.length}건', color: const Color(0xFF0F7B6C)),
                  if (progressTasks.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(label: '진행보고 ${progressTasks.length}건', color: const Color(0xFF2383E2)),
                  ],
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18, color: NotionTheme.textSecondary),
                ],
              ),
            ),
          ),

          // 업무 목록
          if (_expanded) ...[
            if (doneTasks.isNotEmpty) ...[
              _TaskGroupHeader(label: '완료된 업무', icon: Icons.check_circle_outline, color: const Color(0xFF0F7B6C)),
              ...doneTasks.map((t) => _TaskReportTile(task: t, date: widget.date, isDone: true)),
            ],
            if (progressTasks.isNotEmpty) ...[
              _TaskGroupHeader(label: '진행 중 (보고됨)', icon: Icons.timelapse_rounded, color: const Color(0xFF2383E2)),
              ...progressTasks.map((t) => _TaskReportTile(task: t, date: widget.date, isDone: false)),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _TaskGroupHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _TaskGroupHeader({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    child: Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    ),
  );
}

// ── 개별 업무 + 보고 내용
class _TaskReportTile extends StatefulWidget {
  final Task task;
  final DateTime date;
  final bool isDone;
  const _TaskReportTile({required this.task, required this.date, required this.isDone});

  @override
  State<_TaskReportTile> createState() => _TaskReportTileState();
}

class _TaskReportTileState extends State<_TaskReportTile> {
  @override
  Widget build(BuildContext context) {
    final todayReports = widget.task.reports.where((r) =>
      r.createdAt.year == widget.date.year &&
      r.createdAt.month == widget.date.month &&
      r.createdAt.day == widget.date.day
    ).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 업무 정보
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      widget.isDone ? Icons.check_circle_rounded : Icons.timelapse_rounded,
                      size: 14,
                      color: widget.isDone ? const Color(0xFF0F7B6C) : const Color(0xFF2383E2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.task.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: NotionTheme.textPrimary,
                            decoration: widget.isDone ? TextDecoration.lineThrough : null,
                            decorationColor: Colors.grey.shade400,
                          )),
                        if (widget.task.assigneeName != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 11, color: Colors.grey.shade400),
                              const SizedBox(width: 3),
                              Text(widget.task.assigneeName!,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 우선순위
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.task.priority.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(widget.task.priority.label,
                      style: TextStyle(fontSize: 10, color: widget.task.priority.color, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // 보고 내용들
            if (todayReports.isNotEmpty) ...[
              Divider(height: 1, color: Colors.grey.shade200),
              ...todayReports.map((r) => _ReportContent(report: r)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  final TaskReport report;
  const _ReportContent({required this.report});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    decoration: const BoxDecoration(
      color: Color(0xFFF0F7FF),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.notes_outlined, size: 13, color: Color(0xFF2383E2)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.reporterName != null)
                Text(report.reporterName!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2383E2))),
              Text(report.content,
                style: const TextStyle(fontSize: 12, color: NotionTheme.textPrimary, height: 1.5)),
              const SizedBox(height: 2),
              Text(
                '${report.createdAt.hour.toString().padLeft(2,'0')}:${report.createdAt.minute.toString().padLeft(2,'0')} 보고',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
