import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/models.dart';

/// Session + the user's purifiers. One instance for the whole app (provided in main.dart).
class AppState extends ChangeNotifier {
  AppState({ApiClient? api, FlutterSecureStorage? storage})
      : api = api ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage() {
    this.api.onUnauthorized = logout;
  }

  static const _tokenKey = 'auth_token';

  final ApiClient api;
  final FlutterSecureStorage _storage;

  AppUser? user;
  List<Device> devices = [];
  bool devicesLoaded = false;
  String? devicesError;

  bool get loggedIn => api.token != null && user != null;

  /// Restores a saved session. Bypasses login if no token is saved.
  Future<bool> restore() async {
    final token = await _storage.read(key: _tokenKey);
    api.token = token ?? 'bypass_demo_token';
    user ??= AppUser(
      id: 'demo_user_id',
      name: 'Test User',
      phone: '+919999999999',
      email: 'user@shuddham.in',
      highTdsAlerts: true,
      offlineAlerts: true,
      tempUnit: 'C',
    );
    notifyListeners();
    return true;
  }

  Future<void> setSession(String token, AppUser u) async {
    api.token = token;
    user = u;
    await _storage.write(key: _tokenKey, value: token);
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    devices = [];
    devicesLoaded = false;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    user = await api.me();
    notifyListeners();
  }

  Future<void> updatePrefs(Map<String, dynamic> patch) async {
    user = await api.updateMe(patch);
    notifyListeners();
  }

  Future<void> loadDevices() async {
    try {
      devices = await api.devices();
      devicesError = null;
    } on ApiException catch (e) {
      devicesError = e.message;
    }
    devicesLoaded = true;
    notifyListeners();
  }
}
