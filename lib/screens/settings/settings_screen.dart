import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_info.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/widget_service.dart';
import '../../widgets/animated_dialog.dart';
import 'category_management_screen.dart';
import 'export_screen.dart';
import 'import_screen.dart';

/// 设置页面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      user.initial,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(user.displayName),
                  subtitle: Text('@${user.username}'),
                ),
              ),
            ),
          _SectionTitle('外观'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题模式'),
                trailing: DropdownButton<String>(
                  value: settings.themeMode,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                    DropdownMenuItem(value: 'light', child: Text('浅色')),
                    DropdownMenuItem(value: 'dark', child: Text('深色')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await settings.setThemeMode(v);
                  },
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('货币符号'),
                trailing: DropdownButton<String>(
                  value: settings.currency,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: '¥', child: Text('¥ 人民币')),
                    DropdownMenuItem(value: '\$', child: Text('\$ 美元')),
                    DropdownMenuItem(value: '€', child: Text('€ 欧元')),
                    DropdownMenuItem(value: '£', child: Text('£ 英镑')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await settings.setCurrency(v);
                  },
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('分类管理'),
                subtitle: const Text('排序、隐藏、添加分类'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CategoryManagementScreen(),
                )),
              ),
            ],
          ),
          _SectionTitle('AI 记账'),
          _SettingsCard(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.chat_bubble_outline),
                title: const Text('默认使用对话模式'),
                subtitle: const Text('开启后，AI 记账默认进入对话模式；关闭则默认进入批量处理模式'),
                value: settings.aiChatMode,
                onChanged: (v) => settings.setAiChatMode(v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome_outlined),
                title: const Text('识别后自动记入账单'),
                subtitle: const Text('开启后，AI 识别完成将自动保存为账单'),
                value: settings.autoSaveAiBills,
                onChanged: (v) => settings.setAutoSaveAiBills(v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.psychology_outlined),
                title: const Text('AI 导入处理'),
                subtitle: const Text('开启后，非标准格式文件将交给 AI 解析'),
                value: settings.aiImportEnabled,
                onChanged: (v) => settings.setAiImportEnabled(v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.bolt_outlined),
                title: const Text('导入后自动处理'),
                subtitle: const Text('开启后，AI 导入识别成功将自动保存为账单'),
                value: settings.autoProcessImportedBills,
                onChanged: (v) => settings.setAutoProcessImportedBills(v),
              ),
            ],
          ),
          _SectionTitle('数据'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导出账单'),
                subtitle: const Text('导出 CSV 并分享'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ExportScreen(),
                )),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导入账单'),
                subtitle: const Text('从 CSV / Excel 导入账单'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ImportScreen(),
                )),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.widgets_outlined),
                title: const Text('桌面卡片'),
                subtitle: const Text('添加本月账单数据到桌面'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _addDesktopWidget(context),
              ),
            ],
          ),
          _SectionTitle('关于'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('版本'),
                trailing: Text('v${AppInfo.version}',
                    style: const TextStyle(color: Colors.grey)),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('开源许可'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppInfo.name,
                  applicationVersion: AppInfo.version,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 请求添加桌面卡片
  Future<void> _addDesktopWidget(BuildContext context) async {
    try {
      await WidgetService.requestPinWidget();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请按系统提示完成添加'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!context.mounted) return;
      await showInfoDialog(
        context: context,
        title: '添加失败',
        content: e.toString(),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// 设置项卡片容器
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: children),
      ),
    );
  }
}
