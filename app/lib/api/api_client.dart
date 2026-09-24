import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around the Shuddham REST API.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _http = client ?? http.Client(),
        _base = (baseUrl ?? AppConfig.apiUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _http;
  final String _base;
  String? token;

  /// Called when the server rejects the token (expired / revoked).
  void Function()? onUnauthorized;

  Future<Map<String, dynamic>> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final headers = {
      'accept': 'application/json',
      if (body != null) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 20)));
    } on SocketException {
      throw ApiException(0, 'NETWORK', 'No internet connection. Check your network and try again.');
    } on TimeoutException {
      throw ApiException(0, 'TIMEOUT', 'The server took too long to respond. Try again.');
    }

    Map<String, dynamic> data = const {};
    if (res.body.isNotEmpty) {
      try {
        data = (jsonDecode(res.body) as Map).cast<String, dynamic>();
      } catch (_) {}
    }
    if (res.statusCode >= 400) {
      final err = (data['error'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (res.statusCode == 401 && token != null) onUnauthorized?.call();
      throw ApiException(
        res.statusCode,
        err['code'] as String? ?? 'HTTP_${res.statusCode}',
        err['message'] as String? ?? 'Something went wrong (${res.statusCode})',
      );
    }
    return data;
  }

  // ---- Auth ----
  Future<void> sendOtp(String phone, {required bool signup}) =>
      _send('POST', '/api/auth/otp/send', body: {'phone': phone, 'purpose': signup ? 'signup' : 'login'});

  Future<(String, AppUser)> verifyOtp(String phone, String code, {Map<String, String>? profile}) async {
    final d = await _send('POST', '/api/auth/otp/verify', body: {
      'phone': phone,
      'code': code,
      if (profile != null) 'profile': profile,
    });
    return (d['token'] as String, AppUser.fromJson((d['user'] as Map).cast()));
  }

  Future<(String, AppUser)> emailLogin(String email, String password) async {
    final d = await _send('POST', '/api/auth/email/login', body: {'email': email, 'password': password});
    return (d['token'] as String, AppUser.fromJson((d['user'] as Map).cast()));
  }

  // ---- Me ----
  Future<AppUser> me() async => AppUser.fromJson(((await _send('GET', '/api/me'))['user'] as Map).cast());

  Future<AppUser> updateMe(Map<String, dynamic> patch) async =>
      AppUser.fromJson(((await _send('PATCH', '/api/me', body: patch))['user'] as Map).cast());

  Future<void> setPassword(String password) => _send('PUT', '/api/me/password', body: {'password': password});

  // ---- Devices ----
  Future<List<Device>> devices() async {
    final d = await _send('GET', '/api/devices');
    return (d['devices'] as List).map((e) => Device.fromJson((e as Map).cast())).toList();
  }

  Future<Device> device(String id) async {
    final d = await _send('GET', '/api/devices/$id');
    final open = (d['openAlerts'] as List? ?? const []);
    final json = (d['device'] as Map).cast<String, dynamic>()..['openAlerts'] = open;
    return Device.fromJson(json);
  }

  Future<Device> claim(String deviceId, String setupCode) async =>
      Device.fromJson(((await _send('POST', '/api/devices/claim', body: {'deviceId': deviceId, 'pop': setupCode}))['device'] as Map).cast());

  Future<Device> updateDevice(String id, Map<String, dynamic> patch) async =>
      Device.fromJson(((await _send('PATCH', '/api/devices/$id', body: patch))['device'] as Map).cast());

  Future<void> removeDevice(String id) => _send('DELETE', '/api/devices/$id');

  Future<List<HistoryPoint>> history(String id, String range) async {
    final d = await _send('GET', '/api/devices/$id/readings', query: {'range': range});
    return (d['points'] as List).map((e) => HistoryPoint.fromJson((e as Map).cast())).toList();
  }
}
