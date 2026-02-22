import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum ViewMode { board, list }

class AppProvider extends ChangeNotifier {
  List<Department> _departments = [];
  List<Task>       _tasks       = [];

  // UI 상태
  String?  _selectedDeptId;
  ViewMode _viewMode     = ViewMode.board;
  bool     _isSidebarOpen = true;
  bool     _isLoading     = false;
  String?  _error;

  // ── 현재 로그인 사용자 정보 (담당자 필터링용) ───────
  String?  _currentUserName;  // displayName
  String?  _currentUserId;    // user id
  bool     _isAdminOrAbove = true; // master/admin → 전체 보기, user → 본인 업무만

  /// AuthProvider에서 로그인 정보가 바뀔 때 호출
  void setCurrentUser(String? displayName, bool isAdminOrAbove, {String? userId}) {
    _currentUserName  = displayName;
    _currentUserId    = userId;
    _isAdminOrAbove   = isAdminOrAbove;
    notifyListeners();
  }

  // ── Getters ───────────────────────────────────────
  List<Department> get departments   => _departments;
  List<Task>       get tasks         => _tasks;
  String?          get selectedDeptId=> _selectedDeptId;
  ViewMode         get viewMode      => _viewMode;
  bool             get isSidebarOpen => _isSidebarOpen;
  bool             get isLoading     => _isLoading;
  String?          get error         => _error;

  Department? get selectedDept => _selectedDeptId == null
      ? null
      : _departments.firstWhere((d) => d.id == _selectedDeptId,
          orElse: () => _departments.first);

  String get currentPageTitle =>
      _selectedDeptId == null ? '전체 업무' : (selectedDept?.name ?? '업무');

  String get currentPageEmoji =>
      _selectedDeptId == null ? '🏠' : (selectedDept?.emoji ?? '📁');

  // ── 담당자 필터 헬퍼 ─────────────────────────────
  /// user 역할이면 자신이 담당자이거나 담당자 미지정(assignee null) 업무만 표시
  /// master/admin은 전체 표시
  bool _passesUserFilter(Task t) {
    if (_isAdminOrAbove) return true;
    // 담당자 없으면 모두에게 보임
    final hasIds  = t.assigneeIds.isNotEmpty;
    final hasName = t.assigneeName != null && t.assigneeName!.isNotEmpty;
    if (!hasIds && !hasName) return true;
    // assigneeIds 리스트에 현재 유저 ID 포함 여부
    if (_currentUserId != null && hasIds) {
      return t.assigneeIds.contains(_currentUserId);
    }
    // ID 없을 경우 이름으로 fallback
    if (_currentUserName != null && hasName) {
      return t.assigneeName! == _currentUserName;
    }
    return true;
  }

  // ── 필터링 ────────────────────────────────────────
  List<Task> getTasksByStatus(TaskStatus status, {String? deptId}) {
    final id = deptId ?? _selectedDeptId;
    return _tasks.where((t) {
      if (id != null && t.departmentId != id) return false;
      if (t.status != status) return false;
      return _passesUserFilter(t);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Task> getAllFilteredTasks({String? deptId}) {
    final id = deptId ?? _selectedDeptId;
    return _tasks
        .where((t) {
          if (id != null && t.departmentId != id) return false;
          return _passesUserFilter(t);
        })
        .toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ── 통계 (담당자 필터 적용) ──────────────────────────
  List<Task> get _visibleTasks => _tasks.where(_passesUserFilter).toList();
  int get totalAll        => _visibleTasks.length;
  int get totalNotStarted => _visibleTasks.where((t) => t.status == TaskStatus.notStarted).length;
  int get totalInProgress => _visibleTasks.where((t) => t.status == TaskStatus.inProgress).length;
  int get totalDone       => _visibleTasks.where((t) => t.status == TaskStatus.done).length;
  int get totalOverdue    => _visibleTasks.where((t) => t.isOverdue).length;

  int deptCount(String id, TaskStatus s) =>
      _visibleTasks.where((t) => t.departmentId == id && t.status == s).length;
  int deptTotal(String id) =>
      _visibleTasks.where((t) => t.departmentId == id).length;

  Department? getDeptById(String id) {
    try { return _departments.firstWhere((d) => d.id == id); }
    catch (_) { return null; }
  }

  // ── UI 액션 ───────────────────────────────────────
  void selectDept(String? id) { _selectedDeptId = id; notifyListeners(); }
  void toggleViewMode() {
    _viewMode = _viewMode == ViewMode.board ? ViewMode.list : ViewMode.board;
    notifyListeners();
  }
  void toggleSidebar() { _isSidebarOpen = !_isSidebarOpen; notifyListeners(); }

  // ── 데이터 로드 (API) ─────────────────────────────
  Future<void> load() async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      await _refreshAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> _refreshAll() async {
    final deptsData = await api.getDepts();
    final tasksData = await api.getTasks();
    _departments = deptsData.map((d) => Department.fromJson(d)).toList();
    _tasks       = tasksData.map((t) => Task.fromJson(t)).toList();
  }

  Future<void> refreshTasks() async {
    try {
      final tasksData = await api.getTasks();
      _tasks = tasksData.map((t) => Task.fromJson(t)).toList();
      notifyListeners();
    } catch (_) {}
  }

  // ── Department CRUD ───────────────────────────────
  Future<void> addDepartment({
    required String name,
    String emoji = '📁',
    String description = '',
    String? managerName,
  }) async {
    final data = await api.createDept({
      'name': name, 'emoji': emoji,
      'description': description,
      if (managerName != null) 'manager_name': managerName,
    });
    _departments.add(Department.fromJson(data));
    notifyListeners();
  }

  Future<void> updateDepartment(Department d) async {
    final data = await api.updateDept(d.id, {
      'name': d.name, 'emoji': d.emoji,
      'description': d.description,
      'manager_name': d.managerName,
    });
    final i = _departments.indexWhere((x) => x.id == d.id);
    if (i != -1) { _departments[i] = Department.fromJson(data); notifyListeners(); }
  }

  Future<void> deleteDepartment(String id) async {
    await api.deleteDept(id);
    _departments.removeWhere((d) => d.id == id);
    _tasks.removeWhere((t) => t.departmentId == id);
    if (_selectedDeptId == id) _selectedDeptId = null;
    notifyListeners();
  }

  // ── Task CRUD ─────────────────────────────────────
  Future<void> addTask({
    required String title,
    String description = '',
    required String departmentId,
    TaskStatus status   = TaskStatus.notStarted,
    TaskPriority priority = TaskPriority.medium,
    DateTime? startDate,
    DateTime? dueDate,
    String? assigneeName,
    List<String>? assigneeIds,
  }) async {
    final ids = assigneeIds ?? [];
    final data = await api.createTask({
      'title': title, 'description': description,
      'dept_id': departmentId,
      'status':   status.name,
      'priority': priority.name,
      if (assigneeName != null && assigneeName.isNotEmpty) 'assignee_name': assigneeName,
      'assignee_ids': '[${ids.map((e) => '"$e"').join(',')}]',
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (dueDate   != null) 'due_date':   dueDate.toIso8601String(),
    });
    _tasks.insert(0, Task.fromJson(data));
    notifyListeners();
  }

  Future<void> updateTask(Task t) async {
    final ids = t.assigneeIds;
    final data = await api.updateTask(t.id, {
      'title': t.title, 'description': t.description,
      'dept_id': t.departmentId,
      'status':   t.status.name,
      'priority': t.priority.name,
      'assignee_name': t.assigneeName,
      'assignee_ids': '[${ids.map((e) => '"$e"').join(',')}]',
      if (t.startDate != null) 'start_date': t.startDate!.toIso8601String(),
      if (t.dueDate   != null) 'due_date':   t.dueDate!.toIso8601String(),
    });
    final i = _tasks.indexWhere((x) => x.id == t.id);
    if (i != -1) { _tasks[i] = Task.fromJson(data); notifyListeners(); }
  }

  Future<void> updateTaskStatus(String id, TaskStatus s) async {
    final data = await api.updateTaskStatus(id, s.name);
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i != -1) { _tasks[i] = Task.fromJson(data); notifyListeners(); }
  }

  Future<void> deleteTask(String id) async {
    await api.deleteTask(id);
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// 완료 업무를 보드에서 숨기기 (보관함엔 계속 표시)
  Future<void> hideTask(String id) async {
    final data = await api.hideTask(id);
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i != -1) { _tasks[i] = Task.fromJson(data); notifyListeners(); }
  }

  /// 숨긴 업무 복원 (보드에 다시 표시)
  Future<void> unhideTask(String id) async {
    final data = await api.unhideTask(id);
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i != -1) { _tasks[i] = Task.fromJson(data); notifyListeners(); }
  }

  // ── Report CRUD ───────────────────────────────────
  Future<void> addReport(String taskId, {
    required String content, String? reporterName,
  }) async {
    final data = await api.addReport(taskId, content, reporterName);
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i != -1) {
      _tasks[i].reports.add(TaskReport.fromJson(data));
      notifyListeners();
    }
  }

  Future<void> updateReport(String taskId, TaskReport updated) async {
    await api.updateReport(taskId, updated.id, updated.content);
    final ti = _tasks.indexWhere((t) => t.id == taskId);
    if (ti != -1) {
      final ri = _tasks[ti].reports.indexWhere((r) => r.id == updated.id);
      if (ri != -1) { _tasks[ti].reports[ri] = updated; notifyListeners(); }
    }
  }

  Future<void> deleteReport(String taskId, String reportId) async {
    await api.deleteReport(taskId, reportId);
    final ti = _tasks.indexWhere((t) => t.id == taskId);
    if (ti != -1) {
      _tasks[ti].reports.removeWhere((r) => r.id == reportId);
      notifyListeners();
    }
  }

  // ── 일일보고 (API) ────────────────────────────────
  Future<List<Map<String, dynamic>>> getDailyReportDataAsync(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
    final raw = await api.getDailyReport(dateStr);
    return raw.map<Map<String, dynamic>>((item) => {
      'dept' : Department.fromJson(item['dept']),
      'tasks': (item['tasks'] as List).map((t) => Task.fromJson(t)).toList(),
    }).toList();
  }

  // ── 완료 업무 보관함 (로컬 필터) ──────────────────
  List<Task> getCompletedTasks({
    String? deptId, DateTime? from, DateTime? to,
    String? keyword, TaskPriority? priority,
    List<Task>? archiveTasks, // 보관함 전용 목록 (숨긴 항목 포함)
  }) {
    final source = archiveTasks ?? _tasks;
    return source.where((t) {
      if (t.status != TaskStatus.done) return false;
      if (deptId   != null && t.departmentId != deptId) return false;
      if (priority != null && t.priority     != priority) return false;
      if (from != null) {
        final base = t.hiddenAt ?? t.dueDate ?? t.createdAt;
        if (base.isBefore(DateTime(from.year, from.month, from.day))) return false;
      }
      if (to != null) {
        final base  = t.hiddenAt ?? t.dueDate ?? t.createdAt;
        final toEnd = DateTime(to.year, to.month, to.day, 23, 59, 59);
        if (base.isAfter(toEnd)) return false;
      }
      if (keyword != null && keyword.isNotEmpty) {
        final kw = keyword.toLowerCase();
        if (!t.title.toLowerCase().contains(kw) &&
            !(t.assigneeName?.toLowerCase().contains(kw) ?? false) &&
            !t.description.toLowerCase().contains(kw)) return false;
      }
      return true;
    }).toList()..sort((a, b) {
      final ad = a.hiddenAt ?? a.dueDate ?? a.createdAt;
      final bd = b.hiddenAt ?? b.dueDate ?? b.createdAt;
      return bd.compareTo(ad);
    });
  }

  /// 보관함용 완료 항목 서버에서 로드 (숨긴 항목 포함)
  Future<List<Task>> loadArchive({String? deptId}) async {
    final data = await api.getArchive(deptId: deptId);
    return data.map((t) => Task.fromJson(t)).toList();
  }

  // ── 달력용 헬퍼 ──────────────────────────────────
  List<Task> getTasksByDueDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _tasks.where((t) {
      if (t.dueDate != null) {
        final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        if (due == d) return true;
      }
      if (t.startDate != null) {
        final st = DateTime(t.startDate!.year, t.startDate!.month, t.startDate!.day);
        if (st == d) return true;
      }
      if (t.startDate != null && t.dueDate != null) {
        final st  = DateTime(t.startDate!.year, t.startDate!.month, t.startDate!.day);
        final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        if (!d.isBefore(st) && !d.isAfter(due)) return true;
      }
      return false;
    }).toList()..sort((a, b) => a.priority.index.compareTo(b.priority.index));
  }

  Set<DateTime> getDueDatesInMonth(int year, int month) {
    return _tasks
        .where((t) => t.dueDate != null &&
            t.dueDate!.year == year && t.dueDate!.month == month)
        .map((t) => DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day))
        .toSet();
  }

  Map<String, List<Task>> getCalendarDayTasks(DateTime date) {
    final due = _tasks.where((t) =>
        t.dueDate != null &&
        t.dueDate!.year  == date.year  &&
        t.dueDate!.month == date.month &&
        t.dueDate!.day   == date.day).toList();
    final created = _tasks.where((t) =>
        t.createdAt.year  == date.year  &&
        t.createdAt.month == date.month &&
        t.createdAt.day   == date.day).toList();
    return {'due': due, 'created': created};
  }

  Map<DateTime, List<Task>> getMonthlyDueTasks(int year, int month) {
    final map        = <DateTime, List<Task>>{};
    final monthStart = DateTime(year, month, 1);
    final monthEnd   = DateTime(year, month + 1, 0);
    for (final t in _tasks) {
      final taskStart = t.startDate != null
          ? DateTime(t.startDate!.year, t.startDate!.month, t.startDate!.day)
          : (t.dueDate != null
              ? DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day)
              : null);
      final taskEnd = t.dueDate != null
          ? DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day)
          : (t.startDate != null
              ? DateTime(t.startDate!.year, t.startDate!.month, t.startDate!.day)
              : null);
      if (taskStart == null && taskEnd == null) continue;
      final rangeStart = taskStart ?? taskEnd!;
      final rangeEnd   = taskEnd   ?? taskStart!;
      if (rangeEnd.isBefore(monthStart) || rangeStart.isAfter(monthEnd)) continue;
      DateTime cur = rangeStart.isBefore(monthStart) ? monthStart : rangeStart;
      final end    = rangeEnd.isAfter(monthEnd) ? monthEnd : rangeEnd;
      while (!cur.isAfter(end)) {
        map.putIfAbsent(DateTime(cur.year, cur.month, cur.day), () => []).add(t);
        cur = cur.add(const Duration(days: 1));
      }
    }
    return map;
  }

  int get todayReportableCount {
    final today = DateTime.now();
    return _tasks.where((t) =>
        t.status == TaskStatus.done ||
        t.reports.any((r) =>
            r.createdAt.year  == today.year  &&
            r.createdAt.month == today.month &&
            r.createdAt.day   == today.day)).length;
  }
}
