import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

/// 本地用户状态（无注册/登录机制）
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

  /// 启动时确保本地用户可用，直接进入应用
  Future<void> bootstrap() async {
    try {
      _user = await _authService.ensureLocalUser();
    } catch (e) {
      _error = e.toString();
    } finally {
      _initialized = true;
      notifyListeners();
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
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
