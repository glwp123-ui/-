/// song work API 서비스
/// 백엔드 URL 우선순위:
///   1. --dart-define=API_BASE_URL=https://xxx.onrender.com  (빌드 시 주입)
///   2. 웹: 현재 호스트의 8000 포트 자동 감지 (sandbox/로컬 개발)
///   3. 네이티브: http://localhost:8000
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// 빌드 시 --dart-define=API_BASE_URL=... 로 주입 가능
const String _injectedApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

String get _base {
  // 1순위: 빌드 시 주입된 URL
  if (_injectedApiUrl.isNotEmpty) return _injectedApiUrl;
  // 2순위: 웹 - 현재 호스트의 8000 포트
  if (kIsWeb) {
    final origin = Uri.base.origin;
    return origin.replaceFirst(RegExp(r':\d+'), ':8000');
  }
  // 3순위: 로컬 기본값
  return 'http://localhost:8000';
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class ApiService {
  String? _token;

  void setToken(String? token) => _token = token;
  String? get token => _token;
  bool get hasToken => _token != null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── Generic HTTP 메서드 ─────────────────────────────
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    var uri = Uri.parse('$_base$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _parse(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    return _parse(res);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    return _parse(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http.delete(Uri.parse('$_base$path'), headers: _headers)
        .timeout(const Duration(seconds: 15));
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
  Future<List<dynamic>> getUsers() => get('/users/') as Future<List<dynamic>>;

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> body) async =>
      await post('/users/', body);

  Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> body) async =>
      await patch('/users/$id', body);

  Future<void> deleteUser(String id) => delete('/users/$id');

  // ── Departments ─────────────────────────────────────
  Future<List<dynamic>> getDepts() => get('/departments/') as Future<List<dynamic>>;

  Future<Map<String, dynamic>> createDept(Map<String, dynamic> body) async =>
      await post('/departments/', body);

  Future<Map<String, dynamic>> updateDept(String id, Map<String, dynamic> body) async =>
      await patch('/departments/$id', body);

  Future<void> deleteDept(String id) => delete('/departments/$id');

  // ── Tasks ───────────────────────────────────────────
  Future<List<dynamic>> getTasks({String? deptId, String? status}) =>
      get('/tasks/', query: {
        if (deptId != null) 'dept_id': deptId,
        if (status  != null) 'status': status,
      }) as Future<List<dynamic>>;

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> body) async =>
      await post('/tasks/', body);

  Future<Map<String, dynamic>> updateTask(String id, Map<String, dynamic> body) async =>
      await patch('/tasks/$id', body);

  Future<Map<String, dynamic>> updateTaskStatus(String id, String status) async =>
      await patch('/tasks/$id/status', {'status': status});

  Future<void> deleteTask(String id) => delete('/tasks/$id');

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
  Future<List<dynamic>> getDailyReport(String date) =>
      get('/tasks/daily-report', query: {'date': date}) as Future<List<dynamic>>;
}

// 싱글톤
final api = ApiService();
