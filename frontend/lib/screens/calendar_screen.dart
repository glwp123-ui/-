import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/notion_theme.dart';
import '../widgets/task_detail_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay  = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    _selectedDay  = null;
  });

  void _nextMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    _selectedDay  = null;
  });

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month);
      _selectedDay  = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final monthDue = provider.getMonthlyDueTasks(
          _focusedMonth.year, _focusedMonth.month);
        final selectedTasks = _selectedDay != null
          ? provider.getTasksByDueDate(_selectedDay!)
          : <Task>[];

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
                Text('📅 업무 달력',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: NotionTheme.textPrimary)),
                Text('시작일~마감일 기준 일정 관리',
                  style: TextStyle(fontSize: 11, color: NotionTheme.textSecondary)),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: _goToday,
                icon: const Icon(Icons.today_outlined, size: 15),
                label: const Text('오늘', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: NotionTheme.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(width: 4),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1)),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              // 넓은 화면: 좌우 분할, 좁은 화면: 위아래 분할
              final isWide = constraints.maxWidth > 700;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 좌: 달력
                    SizedBox(
                      width: 480,
                      child: _CalendarGrid(
                        focusedMonth: _focusedMonth,
                        selectedDay: _selectedDay,
                        monthDueTasks: monthDue,
                        onPrev: _prevMonth,
                        onNext: _nextMonth,
                        onDayTap: (day) => setState(() {
                          _selectedDay = (_selectedDay != null &&
                            _isSameDay(_selectedDay!, day)) ? null : day;
                        }),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    // 우: 업무 패널
                    Expanded(
                      child: _selectedDay == null
                        ? _MonthOverview(monthDue: monthDue,
                            onDayTap: (d) => setState(() => _selectedDay = d))
                        : _DayPanel(
                            date: _selectedDay!,
                            tasks: selectedTasks,
                            provider: provider,
                          ),
                    ),
                  ],
                );
              }

              // 좁은 화면: 상하 분할
              return Column(
                children: [
                  _CalendarGrid(
                    focusedMonth: _focusedMonth,
                    selectedDay: _selectedDay,
                    monthDueTasks: monthDue,
                    onPrev: _prevMonth,
                    onNext: _nextMonth,
                    onDayTap: (day) => setState(() {
                      _selectedDay = (_selectedDay != null &&
                        _isSameDay(_selectedDay!, day)) ? null : day;
                    }),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _selectedDay == null
                      ? _MonthOverview(monthDue: monthDue,
                          onDayTap: (d) => setState(() => _selectedDay = d))
                      : _DayPanel(
                          date: _selectedDay!,
                          tasks: selectedTasks,
                          provider: provider,
                        ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────────
// 달력 그리드 (셀에 업무 제목 표시)
// ─────────────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final Map<DateTime, List<Task>> monthDueTasks;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(DateTime) onDayTap;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.monthDueTasks,
    required this.onPrev,
    required this.onNext,
    required this.onDayTap,
  });

  bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=일, 1=월 ... 6=토

    // 총 행 수 계산
    final totalCells = startWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 월 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Row(
              children: [
                _NavBtn(icon: Icons.chevron_left, onTap: onPrev),
                Expanded(
                  child: Text(
                    '${focusedMonth.year}년 ${focusedMonth.month}월',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: NotionTheme.textPrimary),
                  ),
                ),
                _NavBtn(icon: Icons.chevron_right, onTap: onNext),
              ],
            ),
          ),

          // ── 요일 헤더
          Container(
            color: const Color(0xFFF9F9F8),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: ['일','월','화','수','목','금','토'].asMap().entries.map((e) {
                Color c = NotionTheme.textSecondary;
                if (e.key == 0) c = const Color(0xFFEB5757);
                if (e.key == 6) c = const Color(0xFF2383E2);
                return Expanded(child: Center(
                  child: Text(e.value,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c)),
                ));
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // ── 날짜 행 (각 행: 날짜번호 + 업무 태그)
          ...List.generate(rowCount, (row) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(7, (col) {
                      final cellIdx = row * 7 + col;
                      final dayNum  = cellIdx - startWeekday + 1;

                      if (dayNum < 1 || dayNum > daysInMonth) {
                        return Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 72),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              border: Border(
                                right: col < 6
                                  ? const BorderSide(color: Color(0xFFEEEEEC))
                                  : BorderSide.none,
                                bottom: const BorderSide(color: Color(0xFFEEEEEC)),
                              ),
                            ),
                          ),
                        );
                      }

                      final date = DateTime(focusedMonth.year, focusedMonth.month, dayNum);
                      final isToday = _isSameDay(date, today);
                      final isSelected = selectedDay != null && _isSameDay(date, selectedDay!);
                      final tasks = monthDueTasks[date] ?? [];
                      final hasOverdue = tasks.any((t) => t.isOverdue);

                      // 요일 색
                      Color numColor = NotionTheme.textPrimary;
                      if (col == 0) numColor = const Color(0xFFEB5757);
                      if (col == 6) numColor = const Color(0xFF2383E2);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onDayTap(date),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 130),
                            constraints: const BoxConstraints(minHeight: 72),
                            decoration: BoxDecoration(
                              color: isSelected
                                ? NotionTheme.accent.withValues(alpha: 0.06)
                                : isToday
                                  ? NotionTheme.accentLight.withValues(alpha: 0.5)
                                  : Colors.white,
                              border: Border(
                                left: isSelected
                                  ? const BorderSide(color: NotionTheme.accent, width: 2)
                                  : BorderSide.none,
                                right: col < 6
                                  ? const BorderSide(color: Color(0xFFEEEEEC))
                                  : BorderSide.none,
                                bottom: const BorderSide(color: Color(0xFFEEEEEC)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 날짜 번호
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(6, 5, 4, 3),
                                  child: Row(
                                    children: [
                                      if (isToday)
                                        Container(
                                          width: 22, height: 22,
                                          decoration: BoxDecoration(
                                            color: NotionTheme.accent,
                                            borderRadius: BorderRadius.circular(11),
                                          ),
                                          child: Center(
                                            child: Text('$dayNum',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white)),
                                          ),
                                        )
                                      else
                                        Text('$dayNum',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                              ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected
                                              ? NotionTheme.accent : numColor)),
                                    ],
                                  ),
                                ),

                                // 업무 태그 (최대 3개)
                                ...tasks.take(3).map((t) => _CalendarTaskChip(task: t)),
                                if (tasks.length > 3)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(5, 1, 4, 2),
                                    child: Text('+${tasks.length - 3}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: hasOverdue
                                          ? const Color(0xFFEB5757)
                                          : NotionTheme.textMuted)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          }),

          // ── 범례
          Container(
            color: const Color(0xFFF9F9F8),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              children: [
                _Legend(color: const Color(0xFF6C5FD4), label: '일정(시작~마감)'),
                const SizedBox(width: 12),
                _Legend(color: NotionTheme.accent, label: '마감일'),
                const SizedBox(width: 12),
                _Legend(color: const Color(0xFFEB5757), label: '기한 초과'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 달력 셀 안 업무 칩
class _CalendarTaskChip extends StatelessWidget {
  final Task task;
  const _CalendarTaskChip({required this.task});

  @override
  Widget build(BuildContext context) {
    // 색상 결정: 기한초과 > 마감일 > 시작일 > 범위 내
    Color bg;
    Color fg;
    if (task.isOverdue) {
      bg = const Color(0xFFEB5757).withValues(alpha: 0.15);
      fg = const Color(0xFFEB5757);
    } else if (task.status == TaskStatus.done) {
      bg = const Color(0xFF0F7B6C).withValues(alpha: 0.12);
      fg = const Color(0xFF0F7B6C);
    } else if (task.startDate != null && task.dueDate != null) {
      bg = const Color(0xFF6C5FD4).withValues(alpha: 0.13);
      fg = const Color(0xFF6C5FD4);
    } else if (task.dueDate != null) {
      bg = NotionTheme.accentLight;
      fg = NotionTheme.accent;
    } else {
      bg = NotionTheme.surface;
      fg = NotionTheme.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 1, 4, 1),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        task.title,
        style: TextStyle(
          fontSize: 9.5,
          color: fg,
          fontWeight: FontWeight.w600,
          decoration: task.status == TaskStatus.done
            ? TextDecoration.lineThrough : null,
          decorationColor: fg,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: NotionTheme.textSecondary)),
    ],
  );
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: NotionTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NotionTheme.border),
      ),
      child: Icon(icon, size: 15, color: NotionTheme.textSecondary),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// 월 전체 개요 (날짜 미선택 시)
// ─────────────────────────────────────────────────────────────────
class _MonthOverview extends StatelessWidget {
  final Map<DateTime, List<Task>> monthDue;
  final void Function(DateTime) onDayTap;

  const _MonthOverview({required this.monthDue, required this.onDayTap});

  @override
  Widget build(BuildContext context) {
    if (monthDue.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📅', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text('이번 달 일정이 없습니다',
              style: TextStyle(color: NotionTheme.textSecondary, fontSize: 14)),
            SizedBox(height: 6),
            Text('업무 추가 시 시작일 또는 마감일을 설정해보세요',
              style: TextStyle(color: NotionTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    final today = DateTime.now();
    final sortedDates = monthDue.keys.toList()..sort();
    final totalTasks = monthDue.values
      .expand((l) => l).map((t) => t.id).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더 요약
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              const Text('날짜를 선택하면 상세 업무를 볼 수 있습니다',
                style: TextStyle(fontSize: 12, color: NotionTheme.textSecondary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: NotionTheme.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('총 $totalTasks건',
                  style: const TextStyle(fontSize: 12,
                    color: NotionTheme.accent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 날짜별 목록
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: sortedDates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final date  = sortedDates[idx];
              final tasks = monthDue[date]!;
              final isToday = date.year == today.year &&
                  date.month == today.month && date.day == today.day;
              final isPast = date.isBefore(
                DateTime(today.year, today.month, today.day));
              final overdue = tasks.where((t) => t.isOverdue).length;
              final wd = ['일','월','화','수','목','금','토'][date.weekday % 7];

              return GestureDetector(
                onTap: () => onDayTap(date),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isToday ? NotionTheme.accent
                        : overdue > 0 ? const Color(0xFFEB5757).withValues(alpha: 0.4)
                        : NotionTheme.border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4, offset: const Offset(0,1)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 날짜 헤더
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                        decoration: BoxDecoration(
                          color: isToday
                            ? NotionTheme.accentLight
                            : isPast && overdue > 0
                              ? const Color(0xFFFFF0EE)
                              : const Color(0xFFF9F9F8),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(9)),
                        ),
                        child: Row(children: [
                          Text('${date.month}/${date.day} ($wd)',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold,
                              color: isToday ? NotionTheme.accent
                                : overdue > 0 ? const Color(0xFFEB5757)
                                : NotionTheme.textPrimary)),
                          const SizedBox(width: 8),
                          if (isToday)
                            _Tag('오늘', NotionTheme.accent)
                          else if (overdue > 0)
                            _Tag('초과 $overdue건', const Color(0xFFEB5757)),
                          const Spacer(),
                          Text('${tasks.length}건',
                            style: const TextStyle(fontSize: 11,
                              color: NotionTheme.textSecondary)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 14,
                            color: NotionTheme.textMuted),
                        ]),
                      ),
                      // 업무 목록 (최대 4개)
                      ...tasks.take(4).map((t) => _MiniRow(task: t)),
                      if (tasks.length > 4)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                          child: Text('+${tasks.length - 4}건 더 있습니다',
                            style: const TextStyle(fontSize: 11,
                              color: NotionTheme.textMuted)),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, color: color,
      fontWeight: FontWeight.bold)),
  );
}

class _MiniRow extends StatelessWidget {
  final Task task;
  const _MiniRow({required this.task});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
    child: Row(
      children: [
        Icon(task.status.icon, size: 13, color: task.status.color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(task.title,
            style: TextStyle(
              fontSize: 13,
              color: NotionTheme.textPrimary,
              decoration: task.status == TaskStatus.done
                ? TextDecoration.lineThrough : null,
              decorationColor: NotionTheme.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        // 시작~마감 표시
        if (task.startDate != null && task.dueDate != null)
          Text(
            '${task.startDate!.month}/${task.startDate!.day}~${task.dueDate!.month}/${task.dueDate!.day}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF6C5FD4)))
        else if (task.dueDate != null)
          Text(
            '~${task.dueDate!.month}/${task.dueDate!.day}',
            style: const TextStyle(fontSize: 10, color: NotionTheme.accent)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: task.priority.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(task.priority.label,
            style: TextStyle(fontSize: 9, color: task.priority.color,
              fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// 날짜 선택 패널 (우측 / 하단)
// ─────────────────────────────────────────────────────────────────
class _DayPanel extends StatelessWidget {
  final DateTime date;
  final List<Task> tasks;
  final AppProvider provider;

  const _DayPanel({required this.date, required this.tasks, required this.provider});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month && date.day == today.day;
    final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
    final wd = ['일','월','화','수','목','금','토'][date.weekday % 7];
    final overdueCount = tasks.where((t) => t.isOverdue).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 날짜 헤더 배너
        Container(
          width: double.infinity,
          color: isToday
            ? NotionTheme.accentLight
            : isPast && overdueCount > 0
              ? const Color(0xFFFFF0EE)
              : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${date.month}월 ${date.day}일 ($wd)',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: isToday ? NotionTheme.accent : NotionTheme.textPrimary)),
                if (isToday)
                  const Text('오늘', style: TextStyle(fontSize: 11, color: NotionTheme.accent))
                else if (isPast && overdueCount > 0)
                  Text('기한 초과 $overdueCount건',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFEB5757))),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tasks.isEmpty
                    ? NotionTheme.surface
                    : isToday
                      ? NotionTheme.accent.withValues(alpha: 0.15)
                      : NotionTheme.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${tasks.length}건',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold,
                    color: tasks.isEmpty ? NotionTheme.textMuted : NotionTheme.accent)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── 업무 목록
        Expanded(
          child: tasks.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 10),
                    const Text('이 날 해당 업무가 없습니다',
                      style: TextStyle(color: NotionTheme.textSecondary, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('업무의 시작일 또는 마감일로 설정하면 표시됩니다',
                      style: TextStyle(color: NotionTheme.textMuted, fontSize: 11)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: tasks.length,
                itemBuilder: (context, idx) => _DayTaskCard(
                  task: tasks[idx],
                  provider: provider,
                ),
              ),
        ),
      ],
    );
  }
}

// ── 날짜 패널 업무 카드
class _DayTaskCard extends StatefulWidget {
  final Task task;
  final AppProvider provider;
  const _DayTaskCard({required this.task, required this.provider});

  @override
  State<_DayTaskCard> createState() => _DayTaskCardState();
}

class _DayTaskCardState extends State<_DayTaskCard> {
  bool _hover = false;

  String _fmtDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final dept = widget.provider.getDeptById(task.departmentId);
    final auth = context.read<AuthProvider>();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => showTaskDetail(context, task),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _hover ? NotionTheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: task.isOverdue
                ? const Color(0xFFEB5757).withValues(alpha: 0.5)
                : _hover
                  ? NotionTheme.accent.withValues(alpha: 0.4)
                  : NotionTheme.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.06 : 0.03),
                blurRadius: _hover ? 8 : 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 상단 (상태 + 제목 + 우선순위)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Icon(task.status.icon, size: 15, color: task.status.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(task.title,
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: NotionTheme.textPrimary,
                          decoration: task.status == TaskStatus.done
                            ? TextDecoration.lineThrough : null,
                          decorationColor: NotionTheme.textMuted),
                        overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: task.priority.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(task.priority.icon, size: 10, color: task.priority.color),
                        const SizedBox(width: 3),
                        Text(task.priority.label,
                          style: TextStyle(fontSize: 10, color: task.priority.color,
                            fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ],
                ),
              ),

              // ── 설명
              if (task.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Text(task.description,
                    style: const TextStyle(fontSize: 12,
                      color: NotionTheme.textSecondary, height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ),

              // ── 메타 행 (부서, 일정, 담당자)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // 부서
                    if (dept != null)
                      _Chip('${dept.emoji} ${dept.name}',
                        NotionTheme.textSecondary, NotionTheme.surface),
                    // 상태
                    _Chip(task.status.label, task.status.color, task.status.bgColor),
                    // 일정 범위
                    if (task.startDate != null || task.dueDate != null)
                      _Chip(
                        () {
                          if (task.startDate != null && task.dueDate != null)
                            return '${_fmtDate(task.startDate!)} ~ ${_fmtDate(task.dueDate!)}';
                          if (task.dueDate != null) return '~${_fmtDate(task.dueDate!)}';
                          return '${_fmtDate(task.startDate!)}~';
                        }(),
                        task.isOverdue
                          ? const Color(0xFFEB5757)
                          : const Color(0xFF6C5FD4),
                        task.isOverdue
                          ? const Color(0xFFFFF0EE)
                          : const Color(0xFFEEECFA),
                      ),
                    // 담당자
                    if (task.assigneeName != null)
                      _Chip('👤 ${task.assigneeName}',
                        NotionTheme.textSecondary, NotionTheme.surface),
                    // 보고 수
                    if (task.reports.isNotEmpty)
                      _Chip('💬 ${task.reports.length}',
                        NotionTheme.textSecondary, NotionTheme.surface),
                  ],
                ),
              ),

              // ── 기한 초과 경고
              if (task.isOverdue)
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEB5757).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFEB5757).withValues(alpha: 0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded, size: 13,
                      color: Color(0xFFEB5757)),
                    SizedBox(width: 5),
                    Text('마감일이 지났습니다. 빠른 처리가 필요합니다.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFEB5757),
                        fontWeight: FontWeight.w500)),
                  ]),
                ),

              // ── 관리자용 빠른 상태 변경
              if (auth.canManageTask && task.status != TaskStatus.done) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (task.status == TaskStatus.notStarted)
                        _QuickBtn('진행 시작', Icons.play_arrow_rounded,
                          const Color(0xFF2383E2), () async {
                            await widget.provider.updateTaskStatus(
                              task.id, TaskStatus.inProgress);
                          }),
                      if (task.status == TaskStatus.inProgress)
                        _QuickBtn('완료 처리', Icons.check_rounded,
                          const Color(0xFF0F7B6C), () async {
                            await widget.provider.updateTaskStatus(
                              task.id, TaskStatus.done);
                          }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const _Chip(this.label, this.fg, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: TextStyle(fontSize: 11, color: fg,
      fontWeight: FontWeight.w500)),
  );
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: color,
          fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
