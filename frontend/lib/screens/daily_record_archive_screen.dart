import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/notion_theme.dart';

// ── 데이터 모델 ──────────────────────────────────────

class DailyRecordItem {
  final String id;
  final String date;
  final int totalTasks;
  final int doneCount;
  final int inProgress;
  final int notStarted;
  final int deptCount;
  final String savedBy;
  final DateTime createdAt;

  DailyRecordItem.fromJson(Map<String, dynamic> j)
      : id          = j['id'],
        date        = j['date'],
        totalTasks  = j['total_tasks'] ?? 0,
        doneCount   = j['done_count']  ?? 0,
        inProgress  = j['in_progress'] ?? 0,
        notStarted  = j['not_started'] ?? 0,
        deptCount   = j['dept_count']  ?? 0,
        savedBy     = j['saved_by']    ?? 'auto',
        createdAt   = DateTime.parse(j['created_at']);
}

// ── 메인 화면 ─────────────────────────────────────────

class DailyRecordArchiveScreen extends StatefulWidget {
  const DailyRecordArchiveScreen({super.key});

  @override
  State<DailyRecordArchiveScreen> createState() =>
      _DailyRecordArchiveScreenState();
}

class _DailyRecordArchiveScreenState
    extends State<DailyRecordArchiveScreen> {
  List<DailyRecordItem> _records = [];
  bool _loading = true;
  bool _saving  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await api.getDailyRecords(limit: 90);
      setState(() {
        _records = raw.map((e) => DailyRecordItem.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _saveToday() async {
    setState(() => _saving = true);
    try {
      await api.saveDailyRecord();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('오늘 업무 현황이 보관함에 저장됐습니다'),
            ]),
            backgroundColor: const Color(0xFF0F7B6C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(DailyRecordItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('보관 기록 삭제'),
        content: Text('${item.date} 기록을 삭제하시겠습니까?\n삭제 후 복구할 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deleteDailyRecord(item.date);
      setState(() => _records.removeWhere((r) => r.date == item.date));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제됐습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 월별 그룹화
  Map<String, List<DailyRecordItem>> _groupByMonth() {
    final map = <String, List<DailyRecordItem>>{};
    for (final r in _records) {
      final parts = r.date.split('-');
      final key = '${parts[0]}년 ${int.parse(parts[1])}월';
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final canManage = context.read<AuthProvider>().canManageTask;
    final grouped   = _groupByMonth();
    final monthKeys = grouped.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20, color: NotionTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📦 일일 업무 보관함',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: NotionTheme.textPrimary)),
            Text('날짜별 자동·수동 저장 기록',
              style: TextStyle(fontSize: 11, color: NotionTheme.textSecondary)),
          ],
        ),
        actions: [
          // 새로고침
          IconButton(
            icon: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh, size: 18,
                  color: NotionTheme.textSecondary),
            onPressed: _loading ? null : _load,
            tooltip: '새로고침',
          ),
          // 총 건수
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5FD4).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.inventory_2_outlined, size: 13,
                color: Color(0xFF6C5FD4)),
              const SizedBox(width: 4),
              Text('${_records.length}일',
                style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.bold, color: Color(0xFF6C5FD4))),
            ]),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),

      // 수동 저장 FAB
      floatingActionButton: canManage
        ? FloatingActionButton.extended(
            onPressed: _saving ? null : _saveToday,
            backgroundColor: const Color(0xFF6C5FD4),
            foregroundColor: Colors.white,
            elevation: 2,
            icon: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 18),
            label: Text(_saving ? '저장 중...' : '오늘 저장',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          )
        : null,

      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : _records.isEmpty
            ? _EmptyView(onSave: canManage ? _saveToday : null)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 90),
                itemCount: monthKeys.length,
                itemBuilder: (ctx, i) {
                  final key    = monthKeys[i];
                  final items  = grouped[key]!;
                  return _MonthGroup(
                    monthLabel: key,
                    items: items,
                    onTap: (item) => _openDetail(item),
                    onDelete: canManage ? _delete : null,
                  );
                },
              ),
    );
  }

  void _openDetail(DailyRecordItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyRecordDetailScreen(date: item.date),
      ),
    );
  }
}

// ── 월별 그룹 위젯 ────────────────────────────────────

class _MonthGroup extends StatefulWidget {
  final String monthLabel;
  final List<DailyRecordItem> items;
  final void Function(DailyRecordItem) onTap;
  final void Function(DailyRecordItem)? onDelete;

  const _MonthGroup({
    required this.monthLabel,
    required this.items,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_MonthGroup> createState() => _MonthGroupState();
}

class _MonthGroupState extends State<_MonthGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NotionTheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          // 월 헤더
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5FD4).withValues(alpha: 0.06),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(9),
                  bottom: _expanded ? Radius.zero : const Radius.circular(9),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined,
                    size: 16, color: Color(0xFF6C5FD4)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.monthLabel,
                      style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold, color: Color(0xFF6C5FD4))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5FD4).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${widget.items.length}일',
                      style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold, color: Color(0xFF6C5FD4))),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: NotionTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // 날짜 행들
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.items.asMap().entries.map((e) {
              final isLast = e.key == widget.items.length - 1;
              return Column(
                children: [
                  _RecordRow(
                    item: e.value,
                    onTap: () => widget.onTap(e.value),
                    onDelete: widget.onDelete != null
                      ? () => widget.onDelete!(e.value)
                      : null,
                  ),
                  if (!isLast)
                    const Divider(height: 1, indent: 14, endIndent: 14),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── 날짜 행 ───────────────────────────────────────────

class _RecordRow extends StatefulWidget {
  final DailyRecordItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _RecordRow({
    required this.item,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_RecordRow> createState() => _RecordRowState();
}

class _RecordRowState extends State<_RecordRow> {
  bool _hover = false;

  String _dayLabel() {
    final parts = widget.item.date.split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${int.parse(parts[1])}월 ${int.parse(parts[2])}일 (${weekdays[d.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isAuto = item.savedBy == 'auto';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hover ? NotionTheme.surface : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              // 날짜 + 저장 방식
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dayLabel(),
                    style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w600, color: NotionTheme.textPrimary)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(
                      isAuto ? Icons.schedule_outlined : Icons.save_outlined,
                      size: 11,
                      color: isAuto
                        ? NotionTheme.textMuted
                        : const Color(0xFF0F7B6C),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isAuto ? '자동 저장' : '수동 저장',
                      style: TextStyle(
                        fontSize: 11,
                        color: isAuto
                          ? NotionTheme.textMuted
                          : const Color(0xFF0F7B6C),
                      ),
                    ),
                  ]),
                ],
              ),

              const Spacer(),

              // 통계 칩들
              _StatChip(
                icon: Icons.check_circle_outline,
                value: '${item.doneCount}',
                label: '완료',
                color: const Color(0xFF0F7B6C),
              ),
              const SizedBox(width: 6),
              _StatChip(
                icon: Icons.timelapse_rounded,
                value: '${item.inProgress}',
                label: '진행',
                color: const Color(0xFF2383E2),
              ),
              const SizedBox(width: 6),
              _StatChip(
                icon: Icons.business_outlined,
                value: '${item.deptCount}',
                label: '부서',
                color: const Color(0xFF6C5FD4),
              ),

              // 삭제 버튼 (호버 시)
              if (_hover && widget.onDelete != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.delete_outline,
                      size: 15, color: Colors.red.shade400),
                  ),
                ),
              ],

              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                size: 16, color: NotionTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatChip({
    required this.icon, required this.value,
    required this.label, required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(value,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(width: 2),
      Text(label,
        style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
    ]),
  );
}

// ── 상세 화면 ─────────────────────────────────────────

class DailyRecordDetailScreen extends StatefulWidget {
  final String date;
  const DailyRecordDetailScreen({super.key, required this.date});

  @override
  State<DailyRecordDetailScreen> createState() =>
      _DailyRecordDetailScreenState();
}

class _DailyRecordDetailScreenState extends State<DailyRecordDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await api.getDailyRecord(widget.date);
      final json = jsonDecode(raw['summary_json'] as String);
      setState(() { _data = json; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _weekdayLabel(String dateStr) {
    final parts = dateStr.split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.year}년 ${d.month}월 ${d.day}일 (${wd[d.weekday - 1]})';
  }

  void _copyAll() {
    if (_data == null) return;
    final buf = StringBuffer();
    final dateStr = _data!['date'] as String;
    final parts = dateStr.split('-');
    buf.writeln('📦 일일 업무 보관함');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('📅 ${parts[0]}년 ${int.parse(parts[1])}월 ${int.parse(parts[2])}일');
    buf.writeln('');

    final depts = _data!['departments'] as List;
    for (final dept in depts) {
      buf.writeln('${dept['dept_emoji']} ${dept['dept_name']}');
      if (dept['manager_name'] != null)
        buf.writeln('   담당: ${dept['manager_name']}');
      buf.writeln('');
      final taskList = dept['tasks'] as List;
      for (final t in taskList) {
        final statusLabel = t['status'] == 'done' ? '✅ 완료' : '🔄 진행';
        buf.writeln('  $statusLabel  ${t['title']}');
        if (t['assignee_name'] != null)
          buf.writeln('      담당자: ${t['assignee_name']}');
        final reports = t['reports'] as List;
        for (final r in reports) {
          buf.writeln('      📝 ${r['content']}');
        }
      }
      buf.writeln('');
    }

    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('✅ 완료 ${_data!['done_count']}건  '
        '🔄 진행 ${_data!['in_progress']}건  '
        '🏢 ${_data!['dept_count']}개 부서');

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('보관 내용이 클립보드에 복사됐습니다'),
        ]),
        backgroundColor: const Color(0xFF6C5FD4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20, color: NotionTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_weekdayLabel(widget.date),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: NotionTheme.textPrimary)),
            const Text('보관된 업무 기록',
              style: TextStyle(fontSize: 11, color: NotionTheme.textSecondary)),
          ],
        ),
        actions: [
          if (_data != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18,
                color: NotionTheme.textSecondary),
              onPressed: _copyAll,
              tooltip: '전체 복사',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18,
              color: NotionTheme.textSecondary),
            onPressed: _load,
            tooltip: '새로고침',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      floatingActionButton: _data != null
        ? FloatingActionButton.extended(
            onPressed: _copyAll,
            backgroundColor: const Color(0xFF6C5FD4),
            foregroundColor: Colors.white,
            elevation: 2,
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('전체 복사',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          )
        : null,
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : _DetailBody(data: _data!),
    );
  }
}

// ── 상세 본문 ─────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DetailBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final depts = data['departments'] as List;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 90),
      children: [
        // 요약 카드
        _SummaryCard(data: data),
        const SizedBox(height: 14),

        // 부서별 섹션
        if (depts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                const Text('📭', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                Text('이 날 기록된 업무가 없습니다',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ]),
            ),
          )
        else
          ...depts.map((dept) => _DeptSection(dept: dept)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C5FD4).withValues(alpha: 0.08),
            const Color(0xFF0F7B6C).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C5FD4).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(child: _SumItem(
            icon: Icons.check_circle_outline,
            value: '${data['done_count']}',
            label: '완료',
            color: const Color(0xFF0F7B6C),
          )),
          Expanded(child: _SumItem(
            icon: Icons.timelapse_rounded,
            value: '${data['in_progress']}',
            label: '진행보고',
            color: const Color(0xFF2383E2),
          )),
          Expanded(child: _SumItem(
            icon: Icons.business_outlined,
            value: '${data['dept_count']}',
            label: '보고 부서',
            color: const Color(0xFF6C5FD4),
          )),
          Expanded(child: _SumItem(
            icon: Icons.assignment_outlined,
            value: '${data['total_tasks']}',
            label: '전체 업무',
            color: const Color(0xFFCB912F),
          )),
        ],
      ),
    );
  }
}

class _SumItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _SumItem({
    required this.icon, required this.value,
    required this.label, required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, size: 20, color: color),
    const SizedBox(height: 4),
    Text(value,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    Text(label,
      style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
  ]);
}

class _DeptSection extends StatefulWidget {
  final Map<String, dynamic> dept;
  const _DeptSection({required this.dept});

  @override
  State<_DeptSection> createState() => _DeptSectionState();
}

class _DeptSectionState extends State<_DeptSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final tasks = widget.dept['tasks'] as List;
    final done  = tasks.where((t) => t['status'] == 'done').toList();
    final prog  = tasks.where((t) => t['status'] == 'inProgress').toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NotionTheme.border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(children: [
        // 부서 헤더
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F7B6C).withValues(alpha: 0.06),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(9),
                bottom: _expanded ? Radius.zero : const Radius.circular(9),
              ),
            ),
            child: Row(children: [
              Text(widget.dept['dept_emoji'] ?? '📁',
                style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.dept['dept_name'] ?? '',
                      style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: NotionTheme.textPrimary)),
                    if (widget.dept['manager_name'] != null)
                      Text('담당: ${widget.dept['manager_name']}',
                        style: const TextStyle(fontSize: 11,
                          color: NotionTheme.textSecondary)),
                  ],
                ),
              ),
              if (done.isNotEmpty)
                _MiniStatBadge(label: '완료 ${done.length}',
                  color: const Color(0xFF0F7B6C)),
              if (prog.isNotEmpty) ...[
                const SizedBox(width: 6),
                _MiniStatBadge(label: '진행 ${prog.length}',
                  color: const Color(0xFF2383E2)),
              ],
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _expanded ? 0 : -0.25,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down,
                  size: 18, color: NotionTheme.textSecondary),
              ),
            ]),
          ),
        ),

        // 업무 목록
        if (_expanded) ...[
          const Divider(height: 1),
          ...tasks.map((t) => _TaskTile(task: t)),
        ],
      ]),
    );
  }
}

class _MiniStatBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniStatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
  );
}

class _TaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final isDone    = task['status'] == 'done';
    final reports   = task['reports'] as List? ?? [];
    final priority  = task['priority'] as String? ?? 'medium';

    final priorityColor = priority == 'high'
      ? const Color(0xFFEB5757)
      : priority == 'low'
        ? const Color(0xFF787774)
        : const Color(0xFFCB912F);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
          color: NotionTheme.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 행
          Row(children: [
            Icon(
              isDone ? Icons.check_circle_rounded : Icons.timelapse_rounded,
              size: 14,
              color: isDone
                ? const Color(0xFF0F7B6C)
                : const Color(0xFF2383E2),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(task['title'] ?? '',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: NotionTheme.textPrimary,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  decorationColor: NotionTheme.textMuted,
                )),
            ),
            // 우선순위 배지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                priority == 'high' ? '높음'
                  : priority == 'low' ? '낮음' : '보통',
                style: TextStyle(fontSize: 10, color: priorityColor,
                  fontWeight: FontWeight.w600),
              ),
            ),
          ]),

          // 담당자
          if (task['assignee_name'] != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const SizedBox(width: 22),
              Icon(Icons.person_outline, size: 11, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Text(task['assignee_name'],
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ],

          // 보고 내용
          if (reports.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...reports.map((r) => Container(
              margin: const EdgeInsets.only(left: 22, bottom: 4),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF2383E2).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r['reporter_name'] != null)
                    Text(r['reporter_name'],
                      style: const TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2383E2))),
                  Text(r['content'] ?? '',
                    style: const TextStyle(fontSize: 12,
                      color: NotionTheme.textPrimary, height: 1.5)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback? onSave;
  const _EmptyView({this.onSave});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('📦', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 16),
        const Text('보관된 기록이 없습니다',
          style: TextStyle(fontSize: 16, color: NotionTheme.textSecondary)),
        const SizedBox(height: 8),
        const Text('매일 자정에 자동으로 저장되거나\n아래 버튼으로 지금 저장할 수 있습니다',
          style: TextStyle(fontSize: 12, color: NotionTheme.textMuted),
          textAlign: TextAlign.center),
        if (onSave != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('지금 저장하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5FD4),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 44, color: Colors.red),
        const SizedBox(height: 12),
        const Text('불러오기 실패',
          style: TextStyle(fontSize: 15, color: NotionTheme.textSecondary)),
        const SizedBox(height: 6),
        Text(error,
          style: const TextStyle(fontSize: 11, color: NotionTheme.textMuted),
          textAlign: TextAlign.center, maxLines: 3),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('다시 시도'),
        ),
      ],
    ),
  );
}
