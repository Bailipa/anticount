/// 用户模型
class AppUser {
  AppUser({
    required this.id,
    required this.username,
    required this.passwordHash,
    this.email,
    this.nickname,
    this.avatar,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as int,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      email: map['email'] as String?,
      nickname: map['nickname'] as String?,
      avatar: map['avatar'] as String?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  final int id;
  final String username;
  final String passwordHash;
  final String? email;
  final String? nickname;
  final String? avatar;
  final DateTime? createdAt;

  /// 显示名称：优先昵称，其次用户名
  String get displayName => nickname?.isNotEmpty == true ? nickname! : username;

  /// 头像首字母（用于 CircleAvatar fallback）
  String get initial =>
      displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'email': email,
      'nickname': nickname,
      'avatar': avatar,
      'created_at': createdAt?.millisecondsSinceEpoch,
    };
  }
}
