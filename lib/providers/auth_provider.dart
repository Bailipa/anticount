import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

/// 用户认证状态
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService);

  final AuthService _authService;

  AppUser? _user;
  bool _initialized = false;
  String? _error;

  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get initialized => _initialized;
  String? get error => _error;

  /// 启动时恢复会话
  Future<void> bootstrap() async {
    try {
      _user = await _authService.currentUser();
    } catch (e) {
      _error = e.toString();
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    try {
      _error = null;
      _user = await _authService.login(
        username: username,
        password: password,
      );
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String password,
    String? email,
  }) async {
    try {
      _error = null;
      _user = await _authService.register(
        username: username,
        password: password,
        email: email,
      );
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String username,
    required String newPassword,
  }) async {
    try {
      _error = null;
      await _authService.resetPassword(
        username: username,
        newPassword: newPassword,
      );
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_user == null) return false;
    try {
      _error = null;
      await _authService.changePassword(
        userId: _user!.id,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount(String password) async {
    if (_user == null) return false;
    try {
      _error = null;
      await _authService.deleteAccount(_user!.id, password);
      _user = null;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 更新用户资料（昵称、头像）
  Future<bool> updateProfile({
    String? nickname,
    String? avatar,
  }) async {
    if (_user == null) return false;
    try {
      _error = null;
      _user = await _authService.updateProfile(
        userId: _user!.id,
        nickname: nickname,
        avatar: avatar,
      );
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 退出登录
  /// [retainData] 为 true 时保留用户记账数据（默认），false 时清除全部交易记录
  Future<void> logout({bool retainData = true}) async {
    if (!retainData && _user != null) {
      await _authService.clearUserData(_user!.id);
    }
    await _authService.clearSession();
    _user = null;
    notifyListeners();
  }
}
