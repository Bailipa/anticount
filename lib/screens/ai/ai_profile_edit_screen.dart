import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/ai_provider.dart';
import '../../services/ai_service.dart';
import '../../widgets/animated_dialog.dart';
import '../../widgets/overlay_dropdown.dart';
import 'ai_error_dialog.dart';

/// AI 配置编辑页面
///
/// 创建或编辑一个 AI 配置（Profile）。
/// 简化布局：配置名称 + 厂商选择（单选）+ API Key + 展示该厂商支持的模型。
/// 同一 Profile 使用同一厂商和 API Key；
/// 文字识别和图像识别的具体模型在配置主界面中切换。
class AiProfileEditScreen extends StatefulWidget {
  const AiProfileEditScreen({super.key, this.profile});

  /// 传入则编辑模式，null 则新建模式
  final AiProfile? profile;

  @override
  State<AiProfileEditScreen> createState() => _AiProfileEditScreenState();
}

class _AiProfileEditScreenState extends State<AiProfileEditScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _apiKeyCtrl;

  /// 当前选中的厂商
  AiVendor? _vendor;

  /// 编辑模式下保留的原有模型 ID（同厂商时沿用，避免覆盖用户在配置界面的选择）
  String? _textModelId;
  String? _multimodalModelId;

  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    // 编辑模式：取 textConfig 的厂商和 API Key 作为默认
    _vendor = p?.textConfig?.vendor;
    _apiKeyCtrl = TextEditingController(text: p?.textConfig?.apiKey ?? '');
    _textModelId = p?.textConfig?.modelId;
    _multimodalModelId = p?.multimodalConfig?.modelId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  /// 切换厂商时重置模型 ID（新厂商的旧 modelId 无效）
  void _onVendorChanged(AiVendor v) {
    if (_vendor == v) return;
    setState(() {
      _vendor = v;
      // 使用新厂商的默认模型
      _textModelId = v.availableModels.isNotEmpty
          ? v.availableModels.first.id
          : null;
      _multimodalModelId = v.multimodalModelIds.isNotEmpty
          ? v.multimodalModelIds.first
          : null;
    });
  }

  /// 跳转到对应厂商的开放平台（获取 API Key）
  Future<void> _launchVendorPlatform() async {
    if (_vendor == null) return;
    final url = Uri.parse(_vendor!.helpUrl);
    // 优先尝试打开 URL，失败时提示用户
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      await showInfoDialog(
        context: context,
        title: '打开失败',
        content: '无法打开 ${_vendor!.label} 的开放平台，请手动访问：\n${_vendor!.helpUrl}',
      );
    }
  }

  /// 保存配置
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      await showInfoDialog(context: context, title: '输入有误', content: '请输入配置名称');
      return;
    }
    if (_vendor == null) {
      await showInfoDialog(context: context, title: '输入有误', content: '请选择厂商');
      return;
    }
    if (_apiKeyCtrl.text.trim().isEmpty) {
      await showInfoDialog(context: context, title: '输入有误', content: '请输入 API Key');
      return;
    }

    // 确定默认模型 ID（若未设置）
    final vendor = _vendor!;
    final textModelId = _textModelId ??
        (vendor.availableModels.isNotEmpty
            ? vendor.availableModels.first.id
            : '');
    if (textModelId.isEmpty) {
      await showInfoDialog(
          context: context, title: '输入有误', content: '该厂商暂无可用模型');
      return;
    }

    setState(() => _verifying = true);

    final ai = context.read<AiProvider>();
    final navigator = Navigator.of(context);
    final isEdit = widget.profile != null;

    bool success = false;
    try {
      final service = AiService();

      // 1. 验证 API Key
      try {
        await service.verifyApiKey(
          vendor: vendor,
          apiKey: _apiKeyCtrl.text.trim(),
          modelId: textModelId,
        );
      } catch (e) {
        if (!mounted) return;
        await showAiErrorDialog(
          context: context,
          title: 'API Key 验证失败',
          error: e.toString(),
        );
        return;
      }

      // 2. 构造配置
      final textConfig = AiModelConfig(
        vendor: vendor,
        apiKey: _apiKeyCtrl.text.trim(),
        modelId: textModelId,
      );
      // 若厂商支持多模态，自动配置多模态（使用默认多模态模型）
      final multimodalConfig = vendor.supportsMultimodal &&
              vendor.multimodalModelIds.isNotEmpty
          ? AiModelConfig(
              vendor: vendor,
              apiKey: _apiKeyCtrl.text.trim(),
              modelId: _multimodalModelId ?? vendor.multimodalModelIds.first,
            )
          : null;

      final profile = AiProfile(
        id: isEdit
            ? widget.profile!.id
            : DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        textConfig: textConfig,
        multimodalConfig: multimodalConfig,
      );
      try {
        if (isEdit) {
          await ai.updateProfile(profile);
        } else {
          await ai.addProfile(profile);
        }
      } catch (e) {
        if (!mounted) return;
        await showAiErrorDialog(
          context: context,
          title: '保存失败',
          error: e.toString(),
        );
        return;
      }

      success = true;
    } finally {
      if (mounted) setState(() => _verifying = false);
    }

    if (success && mounted) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.profile != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑配置' : '新建配置'),
        actions: [
          TextButton(
            onPressed: _verifying ? null : _save,
            child: _verifying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 配置名称
          _SectionTitle('配置名称'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: '例如：我的deepseek',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // 厂商选择（圆角矩形 + 自定义 Overlay 下拉列表）
          _SectionTitle('厂商'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OverlayDropdown<AiVendor>(
              // 启用卷帘门（下拉展开）动画
              animate: true,
              items: AiVendor.values,
              isSelected: (v) => v == _vendor,
              itemLabelOf: (v) =>
                  '${v.label}（${v.supportsMultimodal ? '支持多模态' : '仅文本'}）',
              itemIconOf: (v) => v.supportsMultimodal
                  ? Icons.image_outlined
                  : Icons.text_snippet_outlined,
              onSelected: _onVendorChanged,
              anchor: (context, onTap) => GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _vendor != null
                          ? Theme.of(context).colorScheme.primary.withAlpha(120)
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_vendor != null)
                        Icon(
                          _vendor!.supportsMultimodal
                              ? Icons.image_outlined
                              : Icons.text_snippet_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      else
                        Icon(Icons.business_outlined,
                            size: 18, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _vendor == null
                            ? Text('选择厂商',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 14))
                            : Text(
                                '${_vendor!.label}（${_vendor!.supportsMultimodal ? '支持多模态' : '仅文本'}）',
                                style: const TextStyle(fontSize: 14),
                              ),
                      ),
                      // 下拉箭头
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 选择厂商后提供跳转开放平台按钮（获取 API Key）
          if (_vendor != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _launchVendorPlatform,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text('前往 ${_vendor!.label} 开放平台'),
                ),
              ),
            ),

          // API Key
          if (_vendor != null) ...[
            _SectionTitle('API Key'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _apiKeyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                          hintText: 'sk-...',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'API 地址：${_vendor!.baseUrl}/chat/completions',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 该厂商支持的模型列表（仅展示，不可选择）
            _SectionTitle('API 支持模型'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final model in _vendor!.availableModels)
                      ListTile(
                        leading: Icon(
                          model.isMultimodal
                              ? Icons.image_outlined
                              : Icons.text_snippet_outlined,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        title: Text(model.id),
                        subtitle: Text(
                          [
                            model.isMultimodal ? '多模态' : '文本',
                            if (model.description != null) model.description!,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 11),
                        ),
                        dense: true,
                      ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
          // 使用说明
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16),
                        SizedBox(width: 6),
                        Text('使用说明',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '· 每个 Profile 使用同一厂商和 API Key\n'
                      '· 保存后可在配置主界面切换具体的文字/图像识别模型\n'
                      '· 文字识别可用所有模型，图像识别仅可用多模态模型\n'
                      '· DeepSeek 仅支持文本，Kimi 支持多模态',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
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
