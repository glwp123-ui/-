import 'package:flutter/material.dart';

// ───────────────────────────────────────────
// Task Status & Priority
// ───────────────────────────────────────────
enum TaskStatus { notStarted, inProgress, done }
enum TaskPriority { low, medium, high }

extension TaskStatusExt on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.notStarted: return '미시작';
      case TaskStatus.inProgress: return '진행중';
      case TaskStatus.done:       return '완료';
    }
  }
  Color get color {
    switch (this) {
      case TaskStatus.notStarted: return const Color(0xFF9B9B9B);
      case TaskStatus.inProgress: return const Color(0xFF2383E2);
      case TaskStatus.done:       return const Color(0xFF0F7B6C);
    }
  }
  Color get bgColor {
    switch (this) {
      case TaskStatus.notStarted: return const Color(0xFFF1F1EF);
      case TaskStatus.inProgress: return const Color(0xFFDCEEFD);
      case TaskStatus.done:       return const Color(0xFFDDEDEA);
    }
  }
  IconData get icon {
    switch (this) {
      case TaskStatus.notStarted: return Icons.radio_button_unchecked;
      case TaskStatus.inProgress: return Icons.timelapse_rounded;
      case TaskStatus.done:       return Icons.check_circle_rounded;
    }
  }
}

extension TaskPriorityExt on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low:    return '낮음';
      case TaskPriority.medium: return '보통';
      case TaskPriority.high:   return '높음';
    }
  }
  Color get color {
    switch (this) {
      case TaskPriority.low:    return const Color(0xFF787774);
      case TaskPriority.medium: return const Color(0xFFCB912F);
      case TaskPriority.high:   return const Color(0xFFEB5757);
    }
  }
  IconData get icon {
    switch (this) {
      case TaskPriority.low:    return Icons.arrow_downward_rounded;
      case TaskPriority.medium: return Icons.remove_rounded;
      case TaskPriority.high:   return Icons.arrow_upward_rounded;
    }
  }
}

// ───────────────────────────────────────────
// TaskReport  (업무 중간/최종 보고)
// ───────────────────────────────────────────
class TaskReport {
  final String id;
  String content;       // 보고 내용
  final DateTime createdAt;
  String? reporterName; // 작성자

  TaskReport({
    required this.id,
    required this.content,
    required this.createdAt,
    this.reporterName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'reporterName': reporterName,
  };

  factory TaskReport.fromJson(Map<String, dynamic> j) => TaskReport(
    id: j['id'],
    content: j['content'] ?? '',
    createdAt: DateTime.parse(j['created_at'] ?? j['createdAt']),
    reporterName: j['reporter_name'] ?? j['reporterName'],
  );
}

// ───────────────────────────────────────────
// Department
// ───────────────────────────────────────────
class Department {
  final String id;
  String name;
  String emoji;
  String description;
  String? managerName;

  Department({
    required this.id,
    required this.name,
    this.emoji = '📁',
    this.description = '',
    this.managerName,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'emoji': emoji,
    'description': description, 'managerName': managerName,
  };

  factory Department.fromJson(Map<String, dynamic> j) => Department(
    id: j['id'], name: j['name'], emoji: j['emoji'] ?? '📁',
    description: j['description'] ?? '',
    // API는 manager_name, 로컬은 managerName
    managerName: j['manager_name'] ?? j['managerName'],
  );
}

// ───────────────────────────────────────────
// Task
// ───────────────────────────────────────────
class Task {
  final String id;
  String title;
  String description;
  String departmentId;
  List<String> departmentIds;
  /// true = department_ids가 API에서 명시적으로 지정된 업무
  /// false = 구버전 업무 (department_ids null, dept_id만 있음)
  bool hasExplicitDeptIds;
  TaskStatus status;
  TaskPriority priority;
  DateTime createdAt;
  DateTime? startDate;
  DateTime? dueDate;
  List<String> assigneeNames;
  List<TaskReport> reports;
  bool isHidden;
  DateTime? hiddenAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.departmentId,
    List<String>? departmentIds,
    this.hasExplicitDeptIds = false,
    this.status = TaskStatus.notStarted,
    this.priority = TaskPriority.medium,
    required this.createdAt,
    this.startDate,
    this.dueDate,
    List<String>? assigneeNames,
    List<TaskReport>? reports,
    this.isHidden = false,
    this.hiddenAt,
  }) : departmentIds = (departmentIds != null && departmentIds.isNotEmpty)
            ? departmentIds
            : [departmentId],
       assigneeNames = assigneeNames ?? [],
       reports = reports ?? [];

  /// 하위 호환: 첫 번째 담당자 이름 (단일 담당자 표시용)
  String? get assigneeName => assigneeNames.isNotEmpty ? assigneeNames.first : null;

  bool get isOverdue =>
      dueDate != null && status != TaskStatus.done && DateTime.now().isAfter(dueDate!);

  /// 오늘 날짜에 작성된 보고 개수
  int get todayReportCount {
    final today = DateTime.now();
    return reports.where((r) =>
      r.createdAt.year == today.year &&
      r.createdAt.month == today.month &&
      r.createdAt.day == today.day
    ).length;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'departmentId': departmentId, 'departmentIds': departmentIds,
    'status': status.index,
    'priority': priority.index, 'createdAt': createdAt.toIso8601String(),
    'startDate': startDate?.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'assigneeNames': assigneeNames,
    'reports': reports.map((r) => r.toJson()).toList(),
  };

  static List<String> _parseNames(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        if (raw.startsWith('[')) {
          return raw
              .replaceAll('[', '').replaceAll(']', '')
              .replaceAll('"', '').replaceAll("'", '')
              .split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  factory Task.fromJson(Map<String, dynamic> j) {
    // status: API는 문자열, 로컬은 int index
    TaskStatus parseStatus(dynamic s) {
      if (s is String) return TaskStatus.values.firstWhere((v) => v.name == s,
          orElse: () => TaskStatus.notStarted);
      return TaskStatus.values[s ?? 0];
    }
    TaskPriority parsePriority(dynamic p) {
      if (p is String) return TaskPriority.values.firstWhere((v) => v.name == p,
          orElse: () => TaskPriority.medium);
      return TaskPriority.values[p ?? 1];
    }
    final rawDeptIds = j['department_ids'];   // API 원본 null 여부 확인
    final parsedDeptIds = _parseNames(rawDeptIds ?? j['departmentIds']);
    return Task(
      id: j['id'], title: j['title'], description: j['description'] ?? '',
      // API는 dept_id, 로컬은 departmentId
      departmentId: j['dept_id'] ?? j['departmentId'] ?? '',
      departmentIds: parsedDeptIds,
      // API에서 department_ids 값이 실제로 내려온 경우에만 true
      hasExplicitDeptIds: rawDeptIds != null && rawDeptIds.toString().length > 2,
      status:   parseStatus(j['status']),
      priority: parsePriority(j['priority']),
      createdAt:  DateTime.parse(j['created_at'] ?? j['createdAt']),
      startDate:  (j['start_date'] ?? j['startDate']) != null
          ? DateTime.parse(j['start_date'] ?? j['startDate'])
          : null,
      dueDate:    (j['due_date'] ?? j['dueDate']) != null
          ? DateTime.parse(j['due_date'] ?? j['dueDate'])
          : null,
      assigneeNames: _parseNames(j['assignee_ids'] ?? j['assigneeNames']),
      reports: j['reports'] != null
          ? (j['reports'] as List).map((r) => TaskReport.fromJson(r)).toList()
          : [],
      isHidden: j['is_hidden'] ?? false,
      hiddenAt: (j['hidden_at']) != null
          ? DateTime.parse(j['hidden_at'])
          : null,
    );
  }
}
