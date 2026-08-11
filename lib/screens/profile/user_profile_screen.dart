import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../constants/app_info.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated_dialog.dart';
import '../settings/settings_screen.dart';

/// 用户界面（"我的" Tab）
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenu(context, value),
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'version',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('版本 v${AppInfo.version}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          const SizedBox(height: 24),
          // 头像 + 昵称 + 用户名
          Center(child: _AvatarPicker(user: user)),
          const SizedBox(height: 12),
          Center(child: _NicknameEditor(user: user)),
          if (user != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                '@${user.username}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 24),
          // 账号信息卡片
          if (user != null) _AccountInfoCard(user: user),
          const SizedBox(height: 16),
          // 功能入口
          _MenuCard(
            items: [
              _MenuItem(
                icon: Icons.settings_outlined,
                title: '设置',
                subtitle: '主题、货币、账户安全',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenu(BuildContext context, String value) async {
    if (value == 'version') {
      await showInfoDialog(
        context: context,
        title: '关于 ${AppInfo.name}',
        content: '版本：${AppInfo.version}\n${AppInfo.copyright}',
      );
    }
  }
}

/// 账号信息卡片
class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final created = user.createdAt;
    final createdText = created == null
        ? '-'
        : '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.alternate_email),
                title: const Text('用户名'),
                trailing: Text(
                  user.username,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('注册时间'),
                trailing: Text(
                  createdText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 通用菜单卡片
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items});
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              items[i],
              if (i < items.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      onTap: onTap,
    );
  }
}

/// 头像选择器（支持相机/相册/删除）
class _AvatarPicker extends StatefulWidget {
  const _AvatarPicker({required this.user});
  final AppUser? user;

  @override
  State<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<_AvatarPicker> {
  bool _saving = false;

  Future<void> _showSourceSheet() async {
    final user = widget.user;
    if (user == null) return;

    final hasAvatar = user.avatar != null && user.avatar!.isNotEmpty;

    final source = await showModalBottomSheet<_AvatarSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, _AvatarSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, _AvatarSource.gallery),
            ),
            if (hasAvatar)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(ctx).colorScheme.error),
                title: Text('删除头像',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () => Navigator.pop(ctx, _AvatarSource.delete),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;
    switch (source) {
      case _AvatarSource.camera:
        await _pickImage(ImageSource.camera);
      case _AvatarSource.gallery:
        await _pickImage(ImageSource.gallery);
      case _AvatarSource.delete:
        await _deleteAvatar();
    }
  }

  Future<void> _pickImage(ImageSource src) async {
    final user = widget.user;
    if (user == null) return;

    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: src,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xfile == null) return;

    setState(() => _saving = true);

    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(xfile.path);
    final destPath = p.join(dir.path, 'avatar_${user.id}$ext');
    final sourceFile = File(xfile.path);
    await sourceFile.copy(destPath);

    final ok = await authProvider.updateProfile(
      nickname: user.nickname,
      avatar: destPath,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('头像已更新'),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      await showInfoDialog(
        context: context,
        title: '更新失败',
        content: '头像更新失败，请重试',
      );
    }
  }

  Future<void> _deleteAvatar() async {
    final user = widget.user;
    if (user == null) return;

    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);

    // 删除本地头像文件
    if (user.avatar != null) {
      final file = File(user.avatar!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    final ok = await authProvider.updateProfile(
      nickname: user.nickname,
      avatar: null,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('头像已删除'),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      await showInfoDialog(
        context: context,
        title: '删除失败',
        content: '头像删除失败，请重试',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final avatarPath = user?.avatar;

    return GestureDetector(
      onTap: _saving ? null : _showSourceSheet,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundImage:
                avatarPath != null ? FileImage(File(avatarPath)) : null,
            child: avatarPath == null
                ? Text(
                    user?.initial ?? '?',
                    style: TextStyle(
                      fontSize: 36,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AvatarSource { camera, gallery, delete }

/// 昵称编辑器
class _NicknameEditor extends StatefulWidget {
  const _NicknameEditor({required this.user});
  final AppUser? user;

  @override
  State<_NicknameEditor> createState() => _NicknameEditorState();
}

class _NicknameEditorState extends State<_NicknameEditor> {
  Future<void> _edit() async {
    final user = widget.user;
    if (user == null) return;

    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    // 对话框内部管理 TextEditingController 生命周期，返回输入的文本或 null
    final text = await showTextInputDialog(
      context: context,
      title: '修改昵称',
      hintText: '请输入昵称（最多 20 个字符）',
      initialValue: user.nickname ?? '',
      confirmText: '保存',
      cancelText: '取消',
      maxLength: 20,
    );

    // 用户取消则直接返回
    if (text == null || text.isEmpty) return;

    final ok = await authProvider.updateProfile(
      nickname: text,
      avatar: user.avatar,
    );

    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('昵称已更新'),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      await showInfoDialog(
        context: context,
        title: '更新失败',
        content: '昵称更新失败，请重试',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return InkWell(
      onTap: _edit,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user?.displayName ?? '未登录',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              size: 16,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
