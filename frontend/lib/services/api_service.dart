/// song work API 서비스
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// 백엔드 URL (Render 배포 주소 고정)
const String _productionApiUrl = 'https://1-mgt1.onrender.com';

// 빌드 시 --dart-define=API_BASE_URL=... 로 주입 가능 (오버라이드용)
const String _injectedApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

String get _base {
  if (_injectedApiUrl.isNotEmpty) return _injectedApiUrl;
  if (kIsWeb) return _productionApiUrl;
  return 'http://localhost:8000';
}

// Render 무료 플랜 슬립 모드 대응 - 타임아웃 60초
const _kTimeout = Duration(seconds: 60);

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class ApiService {
  String? _token;
  bool _serverAwake = false; // 서버 깨어있는지 여부

  void setToken(String? token) => _token = token;
  String? get token => _token;
  bool get hasToken => _token != null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // 서버 워밍업 (Render 슬립 모드 해제)
  Future<void> wakeUp() async {
    if (_serverAwake) return;
    try {
      await http.get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 60));
      _serverAwake = true;
    } catch (_) {}
  }

  // ── Generic HTTP 메서드 ─────────────────────────────
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    var uri = Uri.parse('$_base$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers).timeout(_kTimeout);
    return _parse(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(_kTimeout);
    return _parse(res);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(_kTimeout);
    return _parse(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http.delete(Uri.parse('$_base$path'), headers: _headers)
        .timeout(_kTimeout);
    return _parse(res);
  }

  dynamic _parse(http.Response res) {
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body.isEmpty) return null;
      return jsonDecode(body);
    }
    String msg = '서버 오류 (${res.statusCode})';
    try {
      final j = jsonDecode(body);
      msg = j['detail'] ?? msg;
    } catch (_) {}
    throw ApiException(res.statusCode, msg);
  }

  // ── Auth ────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String username, String password) async {
    final data = await post('/auth/login', {
      'username': username,
      'password': password,
    });
    _token = data['access_token'];
    return data;
  }

  Future<void> changePassword(String userId, String newPassword) async {
    await post('/auth/change-password', {
      'user_id': userId,
      'new_password': newPassword,
    });
  }

  // ── Users ───────────────────────────────────────────
  Future<List<dynamic>> getUsers() async {
    final data = await get('/users/');
    return List<dynamic>.from(data as List);
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> body) async =>
      await post('/users/', body);

  Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> body) async =>
      await patch('/users/$id', body);

  Future<void> deleteUser(String id) => delete('/users/$id');

  // ── Departments ─────────────────────────────────────
  Future<List<dynamic>> getDepts() async {
    final data = await get('/departments/');
    return List<dynamic>.from(data as List);
  }

  Future<Map<String, dynamic>> createDept(Map<String, dynamic> body) async =>
      await post('/departments/', body);

  Future<Map<String, dynamic>> updateDept(String id, Map<String, dynamic> body) async =>
      await patch('/departments/$id', body);

  Future<void> deleteDept(String id) => delete('/departments/$id');

  // ── Tasks ───────────────────────────────────────────
  Future<List<dynamic>> getTasks({String? deptId, String? status}) async {
    final data = await get('/tasks/', query: {
      if (deptId != null) 'dept_id': deptId,
      if (status  != null) 'status': status,
    });
    return List<dynamic>.from(data as List);
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> body) async =>
      await post('/tasks/', body);

  Future<Map<String, dynamic>> updateTask(String id, Map<String, dynamic> body) async =>
      await patch('/tasks/$id', body);

  Future<Map<String, dynamic>> updateTaskStatus(String id, String status) async =>
      await patch('/tasks/$id/status', {'status': status});

  Future<void> deleteTask(String id) => delete('/tasks/$id');

  /// 완료 업무를 보드에서 숨기기 (보관함엔 유지)
  Future<Map<String, dynamic>> hideTask(String id) async =>
      await patch('/tasks/$id/hide', {});

  /// 숨긴 업무 복원
  Future<Map<String, dynamic>> unhideTask(String id) async =>
      await patch('/tasks/$id/unhide', {});

  /// 완료 보관함 조회 (숨긴 항목 포함)
  Future<List<dynamic>> getArchive({String? deptId}) async {
    final data = await get('/tasks/archive', query: {
      if (deptId != null) 'dept_id': deptId,
    });
    return List<dynamic>.from(data as List);
  }

  // ── Reports ─────────────────────────────────────────
  Future<Map<String, dynamic>> addReport(
      String taskId, String content, String? reporter) async =>
      await post('/tasks/$taskId/reports', {
        'content': content,
        if (reporter != null) 'reporter_name': reporter,
      });

  Future<Map<String, dynamic>> updateReport(
      String taskId, String reportId, String content) async =>
      await patch('/tasks/$taskId/reports/$reportId', {'content': content});

  Future<void> deleteReport(String taskId, String reportId) =>
      delete('/tasks/$taskId/reports/$reportId');

  // ── Daily Report ────────────────────────────────────
  Future<List<dynamic>> getDailyReport(String date) async {
    final data = await get('/tasks/daily-report', query: {'date': date});
    return List<dynamic>.from(data as List);
  }
}

// 싱글톤
final api = ApiService();
