import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';

/// 本地用户服务
///
/// 无注册/登录机制，首次启动自动创建默认本地用户，
/// 会话通过 SharedPreferences 持久化。
class AuthService {
  AuthService(this._db);
  final Database _db;

  static const _kSessionKey = 'session_user_id';

  String _hash(String password) {
    return sha256.convert(utf8.encode('anticount::$password')).toString();
  }

  /// 确保存在本地默认用户，并返回当前生效用户
  Future<AppUser> ensureLocalUser() async {
    final existing = await currentUser();
    if (existing != null) return existing;

    final id = await _db.insert('users', {
      'username': 'local',
      'password_hash': _hash('local'),
      'nickname': '本地用户',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _saveSession(id);
    final rows = await _db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return AppUser.fromMap(rows.first);
  }

  /// 更新用户资料（昵称、头像）
  Future<AppUser> updateProfile({
    required int userId,
    String? nickname,
    String? avatar,
  }) async {
    await _db.update(
      'users',
      {
        'nickname': nickname?.trim().isEmpty == true ? null : nickname?.trim(),
        'avatar': avatar,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
    final rows = await _db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('本地用户不存在');
    }
    return AppUser.fromMap(rows.first);
  }

  /// 保存会话
  Future<void> _saveSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSessionKey, userId);
  }

  /// 读取当前用户，未初始化则返回 null
  Future<AppUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_kSessionKey);
    if (userId == null) return null;
    final rows = await _db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }
}
