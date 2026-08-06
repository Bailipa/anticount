import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ai_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/ai_service.dart';
import '../../widgets/animated_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/overlay_dropdown.dart';
import 'ai_profile_edit_screen.dart';

/// AI 配置页面
///
/// 上半部分按"文字识别 / 图像识别"分组展示当前选中模型，
/// 展开后按 Profile 分组列出该厂商所有可选模型，用户可任意切换。
/// 下半部分为配置管理（创建 / 编辑 / 删除 Profile）。
class AiConfigScreen extends StatelessWidget {
  const AiConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('AI 配置')),
      body: ai.profiles.isEmpty
          ? _buildEmpty(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              children: [
                // 自动记账开关
                _AutoSaveSwitch(),
                const SizedBox(height: 8),
                // 文字识别分组
                _RecognitionSection(
                  title: '文字识别',
                  icon: Icons.text_fields_outlined,
                  isMultimodal: false,
                ),
                const SizedBox(height: 8),
                // 图像识别分组
                _RecognitionSection(
                  title: '图像识别',
                  icon: Icons.image_outlined,
                  isMultimodal: true,
                ),
                const SizedBox(height: 16),
                // 配置管理
                _ManagementSection(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiProfileEditScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('新建配置'),
      ),
    );
  }

  /// 空状态
  Widget _buildEmpty(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off,
      iconSize: 64,
      iconColor: Theme.of(context).colorScheme.outline,
      title: '尚未创建 AI 配置',
      titleStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      gap: 16,
      subtitle: '点击右下角按钮创建第一个配置\n每个配置包含厂商、API Key 和模型选择',
    );
  }
}

/// 自动记账开关
///
/// 允许用户在 AI 配置页面直接开启/关闭「识别后自动记入账单」。
class _AutoSaveSwitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        secondary: const Icon(Icons.auto_awesome_outlined),
        title: const Text('识别后自动记入账单'),
        subtitle: const Text('AI 识别完成自动保存为账单'),
        value: settings.autoSaveAiBills,
        onChanged: (v) => settings.setAutoSaveAiBills(v),
      ),
    );
  }
}

/// 识别类型分组（文字识别 / 图像识别）
///
/// 展开后按 Profile 分组，列出每个 Profile 对应厂商的所有可选模型。
/// 用户点击具体模型即可切换激活的 Profile + 模型。
class _RecognitionSection extends StatelessWidget {
  const _RecognitionSection({
    required this.title,
    required this.icon,
    required this.isMultimodal,
  });

  final String title;
  final IconData icon;
  final bool isMultimodal;

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();

    // 当前激活的 Profile 和模型 ID
    final activeProfile =
        isMultimodal ? ai.activeMultimodalProfile : ai.activeTextProfile;
    final activeModelId =
        isMultimodal ? ai.activeMultimodalModelId : ai.activeTextModelId;

    // 可用的 Profile 列表（有对应配置的）
    final availableProfiles = ai.profiles.where((p) {
      if (isMultimodal) {
        return p.hasMultimodalModel &&
            p.multimodalConfig!.vendor.supportsMultimodal;
      }
      return p.hasTextModel;
    }).toList();

    // 当前选中描述
    final currentText = (activeProfile != null && activeModelId != null)
        ? '${activeProfile.name} - $activeModelId'
        : (availableProfiles.isEmpty ? '暂无可用配置' : '未选择');

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 28, top: 2),
          child: Text(
            currentText,
            style: TextStyle(
              fontSize: 13,
              color: activeProfile != null
                  ? Theme.of(context).colorScheme.onSurface.withAlpha(180)
                  : Colors.red[300],
            ),
          ),
        ),
        children: availableProfiles.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    isMultimodal
                        ? '暂无支持图像识别的配置（需多模态厂商，如 Kimi）'
                        : '暂无可用文字识别配置',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ]
            : [
                for (int i = 0; i < availableProfiles.length; i++) ...[
                  _ProfileModelGroup(
                    profile: availableProfiles[i],
                    isMultimodal: isMultimodal,
                    activeProfileId: activeProfile?.id,
                    activeModelId: activeModelId,
                  ),
                  if (i < availableProfiles.length - 1) const Divider(height: 1),
                ],
              ],
      ),
    );
  }
}

/// 单个 Profile 下的模型列表
///
/// 显示 Profile 名称作为子标题，下面列出该厂商所有可选模型。
/// 文字识别列出所有模型，图像识别仅列出多模态模型。
class _ProfileModelGroup extends StatelessWidget {
  const _ProfileModelGroup({
    required this.profile,
    required this.isMultimodal,
    required this.activeProfileId,
    required this.activeModelId,
  });

  final AiProfile profile;
  final bool isMultimodal;
  final String? activeProfileId;
  final String? activeModelId;

  @override
  Widget build(BuildContext context) {
    final ai = context.read<AiProvider>();
    final vendor = isMultimodal
        ? profile.multimodalConfig!.vendor
        : profile.textConfig!.vendor;

    // 文字识别：列出该厂商所有模型（多模态模型也可用于文字）
    // 图像识别：仅列出多模态模型
    final models = isMultimodal
        ? vendor.availableModels.where((m) => m.isMultimodal).toList()
        : vendor.availableModels;

    // 当前是否选中此 Profile + 模型
    final isThisProfileActive = activeProfileId == profile.id;
    final activeModel = isThisProfileActive ? activeModelId : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile 名称
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.account_tree_outlined,
                    size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  profile.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  vendor.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          // 模型列表（自定义单选样式，避免 RadioListTile 弃用 API）
          for (final model in models)
            _ModelTile(
              modelId: model.id,
              description: model.description,
              selected: isThisProfileActive && activeModel == model.id,
              onTap: () {
                if (isMultimodal) {
                  ai.selectMultimodalModel(profile.id, model.id);
                } else {
                  ai.selectTextModel(profile.id, model.id);
                }
              },
            ),
        ],
      ),
    );
  }
}

/// 单个模型选项（自定义单选样式）
class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.modelId,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String modelId;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // 单选指示器
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modelId,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  if (description != null)
                    Text(
                      description!,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 配置管理区域
///
/// 列出所有 Profile，支持编辑和删除。删除最后一个 Profile 不允许。
class _ManagementSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 20),
                const SizedBox(width: 8),
                const Text('配置管理',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AiProfileEditScreen()),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建'),
                ),
              ],
            ),
            const Divider(),
            for (final profile in ai.profiles)
              _ProfileManageTile(profile: profile),
          ],
        ),
      ),
    );
  }
}

/// 配置管理中的单条 Profile
class _ProfileManageTile extends StatelessWidget {
  const _ProfileManageTile({required this.profile});

  final AiProfile profile;

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();
    final canDelete = ai.profiles.length > 1;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: const Icon(Icons.account_circle_outlined),
      title: Text(profile.name,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        [
          if (profile.hasTextModel)
            '文字：${profile.textConfig!.vendor.label} · ${profile.textConfig!.modelId}',
          if (profile.hasMultimodalModel)
            '图像：${profile.multimodalConfig!.vendor.label} · ${profile.multimodalConfig!.modelId}',
          if (!profile.hasTextModel && !profile.hasMultimodalModel) '未配置模型',
        ].join('\n'),
        style: const TextStyle(fontSize: 12),
      ),
      isThreeLine: true,
      trailing: OverlayDropdown<_MenuItem>(
        // 菜单在三个点按钮下方右对齐弹出
        rightAligned: true,
        items: [
          const _MenuItem(
              value: 'edit', label: '编辑', icon: Icons.edit_outlined),
          if (canDelete)
            const _MenuItem(
                value: 'delete', label: '删除', icon: Icons.delete_outline),
        ],
        itemLabelOf: (item) => item.label,
        itemIconOf: (item) => item.icon,
        onSelected: (item) {
          if (item.value == 'edit') {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AiProfileEditScreen(profile: profile),
            ));
          } else if (item.value == 'delete') {
            _confirmDelete(context, ai, profile);
          }
        },
        anchor: (context, onTap) => IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onTap,
        ),
      ),
    );
  }

  /// 确认删除
  Future<void> _confirmDelete(
    BuildContext context,
    AiProvider ai,
    AiProfile profile,
  ) async {
    final ok = await showConfirmDialog(
      context: context,
      title: '删除配置',
      content: '确认删除配置「${profile.name}」？',
      confirmText: '删除',
      cancelText: '取消',
      danger: true,
    );
    if (ok == true) {
      await ai.removeProfile(profile.id);
    }
  }
}

/// 菜单项数据
class _MenuItem {
  const _MenuItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}
