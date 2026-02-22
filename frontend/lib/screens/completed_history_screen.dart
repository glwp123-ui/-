import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/notion_theme.dart';
import '../widgets/task_detail_sheet.dart';

class CompletedHistoryScreen extends StatefulWidget {
  const CompletedHistoryScreen({super.key});

  @override
  State<CompletedHistoryScreen> createState() => _CompletedHistoryScreenState();
}

class _CompletedHistoryScreenState extends State<CompletedHistoryScreen> {
  // ── 필터 상태
  String? _deptId;
  DateTime? _from;
  DateTime? _to;
  String _keyword = '';
  TaskPriority? _priority;

  final _searchCtrl = TextEditingController();
  int _quickRange = 30; // 0=전체, 7, 30, 90, 180

  // 보관함 전용 데이터 (숨긴 항목 포함)
  List<Task> _archiveTasks = [];
  bool _isLoading = true;
  String? _loadError;

  // 그룹화 모드: 'date' (날짜/월별) or 'dept' (부서별)
  String _groupMode = 'date';

  @override
  void initState() {
    super.initState();
    _applyQuickRange(30);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadArchive());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadArchive() async {
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final provider = context.read<AppProvider>();
      final tasks = await provider.loadArchive();
      setState(() { _archiveTasks = tasks; _isLoading = false; });
    } catch (e) {
      setState(() { _loadError = e.toString(); _isLoading = false; });
    }
  }

  void _applyQuickRange(int days) {
    setState(() {
      _quickRange = days;
      if (days == 0) {
        _from = null;
        _to   = null;
      } else {
        _to   = DateTime.now();
        _from = _to!.subtract(Duration(days: days));
      }
    });
  }

  String _fmtDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}';

  String _fmtMonthKey(DateTime d) =>
    '${d.year}년 ${d.month}월';

  /// 날짜 기준 (hidden_at → due_date → updated_at 순)
  DateTime _getTaskDate(Task t) => t.hiddenAt ?? t.dueDate ?? t.createdAt;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final filtered = provider.getCompletedTasks(
          deptId:   _deptId,
          from:     _from,
          to:       _to,
          keyword:  _keyword.isEmpty ? null : _keyword,
          priority: _priority,
          archiveTasks: _archiveTasks,
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F5),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: NotionTheme.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🗂️ 완료 업무 보관함',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: NotionTheme.textPrimary)),
                Text('완료된 모든 업무 (숨긴 항목 포함)',
                  style: TextStyle(fontSize: 11, color: NotionTheme.textSecondary)),
              ],
            ),
            actions: [
              // 그룹화 토글
              _GroupToggle(mode: _groupMode, onChanged: (m) => setState(() => _groupMode = m)),
              // 새로고침
              IconButton(
                icon: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 18, color: NotionTheme.textSecondary),
                onPressed: _isLoading ? null : _loadArchive,
                tooltip: '새로고침',
              ),
              // 총 건수 배지
              Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F7B6C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 13,
                      color: Color(0xFF0F7B6C)),
                    const SizedBox(width: 4),
                    Text('${filtered.length}건',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: Color(0xFF0F7B6C))),
                  ],
                ),
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
          ),
          body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
              ? _ErrorState(error: _loadError!, onRetry: _loadArchive)
              : Column(
                  children: [
                    // ── 필터 패널
                    _FilterPanel(
                      provider:    provider,
                      selectedDeptId: _deptId,
                      from:        _from,
                      to:          _to,
                      keyword:     _keyword,
                      priority:    _priority,
                      quickRange:  _quickRange,
                      searchCtrl:  _searchCtrl,
                      onDeptChanged: (id) => setState(() => _deptId = id),
                      onRangeChanged: _applyQuickRange,
                      onCustomDate: (from, to) => setState(() {
                        _quickRange = -1;
                        _from = from; _to = to;
                      }),
                      onKeywordChanged: (kw) => setState(() => _keyword = kw),
                      onPriorityChanged: (p) => setState(() => _priority = p),
                      onReset: () => setState(() {
                        _deptId = null; _priority = null; _keyword = '';
                        _searchCtrl.clear();
                        _applyQuickRange(30);
                      }),
                    ),

                    // ── 결과 목록
                    Expanded(
                      child: filtered.isEmpty
                        ? _EmptyState(hasFilter: _deptId != null || _keyword.isNotEmpty
                            || _priority != null)
                        : _groupMode == 'date'
                          ? _DateGroupedList(
                              tasks: filtered,
                              provider: provider,
                              fmtDate: _fmtDate,
                              fmtMonthKey: _fmtMonthKey,
                              getTaskDate: _getTaskDate,
                              onRefresh: _loadArchive,
                            )
                          : _DeptGroupedList(
                              tasks: filtered,
                              provider: provider,
                              fmtDate: _fmtDate,
                              onRefresh: _loadArchive,
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ── 그룹화 모드 토글
class _GroupToggle extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onChanged;
  const _GroupToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _ToggleBtn(
        icon: Icons.calendar_month_outlined,
        label: '날짜',
        selected: mode == 'date',
        onTap: () => onChanged('date'),
      ),
      _ToggleBtn(
        icon: Icons.business_outlined,
        label: '부서',
        selected: mode == 'dept',
        onTap: () => onChanged('dept'),
      ),
    ],
  );
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleBtn({required this.icon, required this.label,
    required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? NotionTheme.accent.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? NotionTheme.accent.withValues(alpha: 0.4) : Colors.transparent),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13,
          color: selected ? NotionTheme.accent : NotionTheme.textSecondary),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11,
          color: selected ? NotionTheme.accent : NotionTheme.textSecondary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────
// 날짜별(월별) 그룹화 목록
// ─────────────────────────────────────────────
class _DateGroupedList extends StatelessWidget {
  final List<Task> tasks;
  final AppProvider provider;
  final String Function(DateTime) fmtDate;
  final String Function(DateTime) fmtMonthKey;
  final DateTime Function(Task) getTaskDate;
  final VoidCallback onRefresh;

  const _DateGroupedList({
    required this.tasks,
    required this.provider,
    required this.fmtDate,
    required this.fmtMonthKey,
    required this.getTaskDate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // 월별 그룹화 (최신 월 먼저)
    final grouped = <String, List<Task>>{};
    final monthOrder = <String>[];
    for (final t in tasks) {
      final key = fmtMonthKey(getTaskDate(t));
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
        monthOrder.add(key);
      }
      grouped[key]!.add(t);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      itemCount: monthOrder.length,
      itemBuilder: (context, idx) {
        final monthKey = monthOrder[idx];
        final monthTasks = grouped[monthKey]!;
        return _MonthSection(
          monthKey: monthKey,
          tasks: monthTasks,
          provider: provider,
          fmtDate: fmtDate,
          getTaskDate: getTaskDate,
          onRefresh: onRefresh,
        );
      },
    );
  }
}

class _MonthSection extends StatefulWidget {
  final String monthKey;
  final List<Task> tasks;
  final AppProvider provider;
  final String Function(DateTime) fmtDate;
  final DateTime Function(Task) getTaskDate;
  final VoidCallback onRefresh;

  const _MonthSection({
    required this.monthKey,
    required this.tasks,
    required this.provider,
    required this.fmtDate,
    required this.getTaskDate,
    required this.onRefresh,
  });

  @override
  State<_MonthSection> createState() => _MonthSectionState();
}

class _MonthSectionState extends State<_MonthSection> {
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
                  const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF6C5FD4)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.monthKey,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: Color(0xFF6C5FD4))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5FD4).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF6C5FD4)),
                      const SizedBox(width: 4),
                      Text('${widget.tasks.length}건',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                          color: Color(0xFF6C5FD4))),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, size: 18,
                      color: NotionTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // 날짜별 서브 그룹핑 (같은 날짜끼리 묶어 표시)
          if (_expanded) ...[
            const Divider(height: 1),
            _DateSubGroups(
              tasks: widget.tasks,
              provider: widget.provider,
              fmtDate: widget.fmtDate,
              getTaskDate: widget.getTaskDate,
              onRefresh: widget.onRefresh,
            ),
          ],
        ],
      ),
    );
  }
}

class _DateSubGroups extends StatelessWidget {
  final List<Task> tasks;
  final AppProvider provider;
  final String Function(DateTime) fmtDate;
  final DateTime Function(Task) getTaskDate;
  final VoidCallback onRefresh;

  const _DateSubGroups({
    required this.tasks,
    required this.provider,
    required this.fmtDate,
    required this.getTaskDate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // 일별 그룹화
    final dayGroups = <String, List<Task>>{};
    final dayOrder = <String>[];
    for (final t in tasks) {
      final d = getTaskDate(t);
      final key = fmtDate(d);
      if (!dayGroups.containsKey(key)) {
        dayGroups[key] = [];
        dayOrder.add(key);
      }
      dayGroups[key]!.add(t);
    }

    return Column(
      children: dayOrder.asMap().entries.map((entry) {
        final dayKey = entry.value;
        final dayTasks = dayGroups[dayKey]!;
        final isLast = entry.key == dayOrder.length - 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 헤더
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C5FD4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(dayKey,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: NotionTheme.textSecondary)),
                  const SizedBox(width: 6),
                  Text('${dayTasks.length}건',
                    style: const TextStyle(fontSize: 11, color: NotionTheme.textMuted)),
                ],
              ),
            ),
            // 해당 날짜 업무들
            ...dayTasks.asMap().entries.map((e) {
              return _CompletedTaskRow(
                task: e.value,
                fmtDate: fmtDate,
                provider: provider,
                onRefresh: onRefresh,
              );
            }),
            if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14),
          ],
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
// 부서별 그룹화 목록 (기존 방식)
// ─────────────────────────────────────────────
class _DeptGroupedList extends StatelessWidget {
  final List<Task> tasks;
  final AppProvider provider;
  final String Function(DateTime) fmtDate;
  final VoidCallback onRefresh;

  const _DeptGroupedList({
    required this.tasks,
    required this.provider,
    required this.fmtDate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // 부서별 그룹핑
    final grouped = <String, List<Task>>{};
    for (final t in tasks) {
      grouped.putIfAbsent(t.departmentId, () => []).add(t);
    }
    final orderedDeptIds = provider.departments
      .map((d) => d.id)
      .where((id) => grouped.containsKey(id))
      .toList();
    final unknownIds = grouped.keys
      .where((id) => !orderedDeptIds.contains(id))
      .toList();
    final allIds = [...orderedDeptIds, ...unknownIds];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      itemCount: allIds.length,
      itemBuilder: (context, idx) {
        final deptId = allIds[idx];
        final deptTasks = grouped[deptId]!;
        final dept = provider.getDeptById(deptId);
        return _DeptSection(
          dept:    dept,
          deptId:  deptId,
          tasks:   deptTasks,
          fmtDate: fmtDate,
          provider: provider,
          onRefresh: onRefresh,
        );
      },
    );
  }
}

class _DeptSection extends StatefulWidget {
  final Department? dept;
  final String deptId;
  final List<Task> tasks;
  final String Function(DateTime) fmtDate;
  final AppProvider provider;
  final VoidCallback onRefresh;

  const _DeptSection({
    required this.dept, required this.deptId,
    required this.tasks, required this.fmtDate,
    required this.provider, required this.onRefresh,
  });

  @override
  State<_DeptSection> createState() => _DeptSectionState();
}

class _DeptSectionState extends State<_DeptSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final dept = widget.dept;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              child: Row(
                children: [
                  Text(dept?.emoji ?? '📁', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dept?.name ?? '알 수 없는 부서',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                            color: NotionTheme.textPrimary)),
                        if (dept?.managerName != null)
                          Text('담당: ${dept!.managerName}',
                            style: const TextStyle(fontSize: 11, color: NotionTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F7B6C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF0F7B6C)),
                      const SizedBox(width: 4),
                      Text('${widget.tasks.length}건',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                          color: Color(0xFF0F7B6C))),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, size: 18,
                      color: NotionTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.tasks.asMap().entries.map((e) {
              final isLast = e.key == widget.tasks.length - 1;
              return Column(
                children: [
                  _CompletedTaskRow(
                    task: e.value,
                    fmtDate: widget.fmtDate,
                    provider: widget.provider,
                    onRefresh: widget.onRefresh,
                  ),
                  if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 필터 패널
// ─────────────────────────────────────────────
class _FilterPanel extends StatelessWidget {
  final AppProvider provider;
  final String? selectedDeptId;
  final DateTime? from;
  final DateTime? to;
  final String keyword;
  final TaskPriority? priority;
  final int quickRange;
  final TextEditingController searchCtrl;
  final ValueChanged<String?> onDeptChanged;
  final ValueChanged<int> onRangeChanged;
  final void Function(DateTime? from, DateTime? to) onCustomDate;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<TaskPriority?> onPriorityChanged;
  final VoidCallback onReset;

  const _FilterPanel({
    required this.provider,
    required this.selectedDeptId,
    required this.from,
    required this.to,
    required this.keyword,
    required this.priority,
    required this.quickRange,
    required this.searchCtrl,
    required this.onDeptChanged,
    required this.onRangeChanged,
    required this.onCustomDate,
    required this.onKeywordChanged,
    required this.onPriorityChanged,
    required this.onReset,
  });

  String _fmtDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final hasFilter = selectedDeptId != null || priority != null
        || keyword.isNotEmpty || quickRange != 30;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onKeywordChanged,
                  decoration: InputDecoration(
                    hintText: '업무 제목, 담당자, 설명 검색...',
                    hintStyle: const TextStyle(fontSize: 13, color: NotionTheme.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 17,
                      color: NotionTheme.textSecondary),
                    suffixIcon: keyword.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 15,
                            color: NotionTheme.textSecondary),
                          onPressed: () {
                            searchCtrl.clear();
                            onKeywordChanged('');
                          },
                        )
                      : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: NotionTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: NotionTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: NotionTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: NotionTheme.accent, width: 1.5),
                    ),
                  ),
                ),
              ),
              if (hasFilter) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onReset,
                  child: const Text('초기화',
                    style: TextStyle(fontSize: 12, color: NotionTheme.textSecondary)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('기간 ',
                  style: TextStyle(fontSize: 11, color: NotionTheme.textMuted,
                    fontWeight: FontWeight.w600)),
                ...[
                  (0,   '전체'),
                  (7,   '7일'),
                  (30,  '30일'),
                  (90,  '3개월'),
                  (180, '6개월'),
                ].map((e) => _FilterChip(
                  label: e.$2,
                  selected: quickRange == e.$1,
                  onTap: () => onRangeChanged(e.$1),
                  color: NotionTheme.accent,
                )),
                _FilterChip(
                  label: quickRange == -1 && from != null
                    ? '${_fmtDate(from!)}~${to != null ? _fmtDate(to!) : ''}'
                    : '직접 선택',
                  selected: quickRange == -1,
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: from != null && to != null
                        ? DateTimeRange(start: from!, end: to!) : null,
                    );
                    if (range != null) onCustomDate(range.start, range.end);
                  },
                  color: const Color(0xFF6C5FD4),
                  icon: Icons.date_range_outlined,
                ),

                const SizedBox(width: 10),
                Container(width: 1, height: 20, color: NotionTheme.border),
                const SizedBox(width: 10),

                const Text('부서 ',
                  style: TextStyle(fontSize: 11, color: NotionTheme.textMuted,
                    fontWeight: FontWeight.w600)),
                _FilterChip(
                  label: '전체',
                  selected: selectedDeptId == null,
                  onTap: () => onDeptChanged(null),
                  color: NotionTheme.accent,
                ),
                ...provider.departments.map((d) => _FilterChip(
                  label: '${d.emoji} ${d.name}',
                  selected: selectedDeptId == d.id,
                  onTap: () => onDeptChanged(selectedDeptId == d.id ? null : d.id),
                  color: NotionTheme.accent,
                )),

                const SizedBox(width: 10),
                Container(width: 1, height: 20, color: NotionTheme.border),
                const SizedBox(width: 10),

                const Text('우선순위 ',
                  style: TextStyle(fontSize: 11, color: NotionTheme.textMuted,
                    fontWeight: FontWeight.w600)),
                _FilterChip(
                  label: '전체',
                  selected: priority == null,
                  onTap: () => onPriorityChanged(null),
                  color: NotionTheme.accent,
                ),
                ...TaskPriority.values.map((p) => _FilterChip(
                  label: p.label,
                  selected: priority == p,
                  onTap: () => onPriorityChanged(priority == p ? null : p),
                  color: p.color,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;
  const _FilterChip({
    required this.label, required this.selected,
    required this.onTap, required this.color, this.icon,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : NotionTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.5) : NotionTheme.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: selected ? color : NotionTheme.textSecondary),
            const SizedBox(width: 4),
          ],
          Text(label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? color : NotionTheme.textSecondary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
        ],
      ),
    ),
  );
}

// ── 완료 업무 행
class _CompletedTaskRow extends StatefulWidget {
  final Task task;
  final String Function(DateTime) fmtDate;
  final AppProvider provider;
  final VoidCallback onRefresh;
  const _CompletedTaskRow({
    required this.task,
    required this.fmtDate,
    required this.provider,
    required this.onRefresh,
  });

  @override
  State<_CompletedTaskRow> createState() => _CompletedTaskRowState();
}

class _CompletedTaskRowState extends State<_CompletedTaskRow> {
  bool _hover = false;

  Future<void> _toggleHide(BuildContext context) async {
    try {
      if (widget.task.isHidden) {
        await widget.provider.unhideTask(widget.task.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('업무가 보드에 다시 표시됩니다')),
          );
          widget.onRefresh();
        }
      } else {
        await widget.provider.hideTask(widget.task.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('업무가 보드에서 숨겨졌습니다')),
          );
          widget.onRefresh();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final canManage = context.read<AuthProvider>().canManageTask;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => showTaskDetail(context, task),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hover ? NotionTheme.surface : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 완료 아이콘
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.check_circle_rounded,
                  size: 17, color: const Color(0xFF0F7B6C).withValues(alpha: 0.7)),
              ),
              const SizedBox(width: 10),

              // 제목 + 메타
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: task.isHidden ? NotionTheme.textMuted : NotionTheme.textSecondary,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: NotionTheme.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(task.description,
                        style: const TextStyle(fontSize: 12,
                          color: NotionTheme.textMuted, height: 1.4),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        // 숨김 상태 배지
                        if (task.isHidden)
                          _MiniTag(
                            label: '보드에서 숨김',
                            color: const Color(0xFF787774),
                            bg: const Color(0xFFF1F1EF),
                            icon: Icons.archive_outlined,
                          ),
                        // 우선순위
                        _MiniTag(
                          label: task.priority.label,
                          color: task.priority.color,
                          bg: task.priority.color.withValues(alpha: 0.1),
                        ),
                        // 마감일
                        if (task.dueDate != null)
                          _MiniTag(
                            label: '~${widget.fmtDate(task.dueDate!)}',
                            color: NotionTheme.textSecondary,
                            bg: NotionTheme.surface,
                            icon: Icons.event_rounded,
                          ),
                        // 보고 수
                        if (task.reports.isNotEmpty)
                          _MiniTag(
                            label: '보고 ${task.reports.length}건',
                            color: const Color(0xFF6C5FD4),
                            bg: const Color(0xFF6C5FD4).withValues(alpha: 0.1),
                            icon: Icons.chat_bubble_outline_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // 담당자 + 숨기기/복원 버튼
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (task.assigneeName != null) ...[
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: NotionTheme.accentLight,
                      child: Text(
                        task.assigneeName!.isNotEmpty ? task.assigneeName![0] : '?',
                        style: const TextStyle(fontSize: 11,
                          color: NotionTheme.accent, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 3),
                    Text(task.assigneeName!,
                      style: const TextStyle(fontSize: 10, color: NotionTheme.textMuted)),
                  ],
                  if (canManage && _hover) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _toggleHide(context),
                      child: Tooltip(
                        message: task.isHidden ? '보드에 다시 표시' : '보드에서 숨기기',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: task.isHidden
                              ? const Color(0xFF0F7B6C).withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: task.isHidden
                                ? const Color(0xFF0F7B6C).withValues(alpha: 0.3)
                                : Colors.grey.shade300),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              task.isHidden ? Icons.unarchive_outlined : Icons.archive_outlined,
                              size: 11,
                              color: task.isHidden ? const Color(0xFF0F7B6C) : const Color(0xFF787774),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              task.isHidden ? '복원' : '숨기기',
                              style: TextStyle(
                                fontSize: 10,
                                color: task.isHidden ? const Color(0xFF0F7B6C) : const Color(0xFF787774),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 15, color: NotionTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final IconData? icon;
  const _MiniTag({required this.label, required this.color,
    required this.bg, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
        ],
        Text(label, style: TextStyle(fontSize: 10, color: color,
          fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

// ── 빈 상태
class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(hasFilter ? '🔍' : '🗂️', style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 14),
        Text(
          hasFilter ? '조건에 맞는 완료 업무가 없습니다' : '완료된 업무가 없습니다',
          style: const TextStyle(fontSize: 15, color: NotionTheme.textSecondary)),
        const SizedBox(height: 6),
        Text(
          hasFilter
            ? '필터를 변경하거나 초기화해보세요'
            : '업무를 완료하면 여기서 조회할 수 있습니다',
          style: const TextStyle(fontSize: 12, color: NotionTheme.textMuted)),
      ],
    ),
  );
}

// ── 오류 상태
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 44, color: Colors.red),
        const SizedBox(height: 12),
        const Text('데이터를 불러오지 못했습니다',
          style: TextStyle(fontSize: 15, color: NotionTheme.textSecondary)),
        const SizedBox(height: 6),
        Text(error, style: const TextStyle(fontSize: 11, color: NotionTheme.textMuted),
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
