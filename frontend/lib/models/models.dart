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
  TaskStatus status;
  TaskPriority priority;
  DateTime createdAt;
  DateTime? startDate;  // 일정 시작일 (달력에 표시)
  DateTime? dueDate;
  String? assigneeName;
  List<TaskReport> reports; // 중간 보고 목록

  Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.departmentId,
    this.status = TaskStatus.notStarted,
    this.priority = TaskPriority.medium,
    required this.createdAt,
    this.startDate,
    this.dueDate,
    this.assigneeName,
    List<TaskReport>? reports,
  }) : reports = reports ?? [];

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
    'departmentId': departmentId, 'status': status.index,
    'priority': priority.index, 'createdAt': createdAt.toIso8601String(),
    'startDate': startDate?.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(), 'assigneeName': assigneeName,
    'reports': reports.map((r) => r.toJson()).toList(),
  };

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
    return Task(
      id: j['id'], title: j['title'], description: j['description'] ?? '',
      // API는 dept_id, 로컬은 departmentId
      departmentId: j['dept_id'] ?? j['departmentId'] ?? '',
      status:   parseStatus(j['status']),
      priority: parsePriority(j['priority']),
      createdAt:  DateTime.parse(j['created_at'] ?? j['createdAt']),
      startDate:  (j['start_date'] ?? j['startDate']) != null
          ? DateTime.parse(j['start_date'] ?? j['startDate'])
          : null,
      dueDate:    (j['due_date'] ?? j['dueDate']) != null
          ? DateTime.parse(j['due_date'] ?? j['dueDate'])
          : null,
      assigneeName: j['assignee_name'] ?? j['assigneeName'],
      reports: j['reports'] != null
          ? (j['reports'] as List).map((r) => TaskReport.fromJson(r)).toList()
          : [],
    );
  }
}
