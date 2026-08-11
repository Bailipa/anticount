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
  late final TextEditingController _customBaseUrlCtrl;
  late final TextEditingController _customModelCtrl;

  /// 当前选中的厂商
  AiVendor? _vendor;

  /// 编辑模式下保留的原有模型 ID（同厂商时沿用，避免覆盖用户在配置界面的选择）
  String? _textModelId;
  String? _multimodalModelId;

  bool _verifying = false;

  /// 连通性测试状态
  bool _testing = false;
  String? _testMessage;
  bool? _testSuccess;

  bool get _isCustom => _vendor == AiVendor.custom;

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
    // 自定义厂商：回填已保存的 Base URL 与模型名
    final isCustom = _vendor == AiVendor.custom;
    _customBaseUrlCtrl = TextEditingController(
      text: isCustom ? (p?.textConfig?.baseUrl ?? '') : '',
    );
    _customModelCtrl = TextEditingController(
      text: isCustom ? (p?.textConfig?.modelId ?? '') : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apiKeyCtrl.dispose();
    _customBaseUrlCtrl.dispose();
    _customModelCtrl.dispose();
    super.dispose();
  }

  /// 切换厂商时重置模型 ID（新厂商的旧 modelId 无效）
  void _onVendorChanged(AiVendor v) {
    if (_vendor == v) return;
    setState(() {
      _vendor = v;
      if (v == AiVendor.custom) {
        // 自定义：模型名以输入框为准
        _textModelId = _customModelCtrl.text.trim().isEmpty
            ? null
            : _customModelCtrl.text.trim();
        _multimodalModelId = null;
      } else {
        // 预设厂商：使用默认模型
        _textModelId = v.availableModels.isNotEmpty
            ? v.availableModels.first.id
            : null;
        _multimodalModelId = v.multimodalModelIds.isNotEmpty
            ? v.multimodalModelIds.first
            : null;
      }
      _clearTestResult();
    });
  }

  void _clearTestResult() {
    _testMessage = null;
    _testSuccess = null;
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

  /// 当前用于测试/保存的有效 Base URL（自定义取输入框，预设取厂商默认）
  String? get _effectiveBaseUrl => _isCustom ? _customBaseUrlCtrl.text.trim() : null;

  /// 当前用于测试/保存的有效模型 ID
  String? get _effectiveModelId =>
      _isCustom ? _customModelCtrl.text.trim() : _textModelId;

  /// 校验连通性测试的输入是否合法，非法时返回错误信息，合法返回 null
  String? _validateForTest() {
    if (_apiKeyCtrl.text.trim().isEmpty) return '请输入 API Key';
    if (_effectiveModelId == null || _effectiveModelId!.isEmpty) {
      return _isCustom ? '请输入模型名称' : '请选择模型';
    }
    if (_isCustom) {
      final url = _customBaseUrlCtrl.text.trim();
      if (url.isEmpty) return '请输入 API 接口地址 (Base URL)';
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return 'API 接口地址必须以 http:// 或 https:// 开头';
      }
    }
    return null;
  }

  /// 连通性测试：向 API 发送最小化请求，内联展示结果
  Future<void> _testConnection() async {
    final invalid = _validateForTest();
    if (invalid != null) {
      setState(() {
        _testMessage = invalid;
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _clearTestResult();
    });

    try {
      final service = AiService();
      await service.verifyApiKey(
        vendor: _vendor!,
        apiKey: _apiKeyCtrl.text.trim(),
        modelId: _effectiveModelId!,
        baseUrl: _effectiveBaseUrl,
      );
      if (!mounted) return;
      setState(() {
        _testMessage = '连接成功，API Key 与模型配置有效';
        _testSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testMessage = e.toString();
        _testSuccess = false;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// 当前配置实际生效的请求地址（自定义取输入框，预设取厂商默认）
  String _requestEndpoint() {
    final vendor = _vendor;
    if (vendor == null) return '';
    final base = _isCustom
        ? normalizeBaseUrl(_customBaseUrlCtrl.text.trim())
        : normalizeBaseUrl(vendor.baseUrl);
    if (base.isEmpty) return '请填写 Base URL';
    return '$base/chat/completions';
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
    final isCustom = _isCustom;
    final textModelId = _effectiveModelId ??
        (vendor.availableModels.isNotEmpty
            ? vendor.availableModels.first.id
            : '');
    if (textModelId.isEmpty) {
      await showInfoDialog(
          context: context,
          title: '输入有误',
          content: isCustom ? '请输入模型名称' : '该厂商暂无可用模型');
      return;
    }

    // 自定义厂商：校验 Base URL 并规范化为不含尾部斜杠的地址
    String? baseUrl;
    if (isCustom) {
      final rawUrl = _customBaseUrlCtrl.text.trim();
      if (rawUrl.isEmpty) {
        await showInfoDialog(
            context: context, title: '输入有误', content: '请输入 API 接口地址 (Base URL)');
        return;
      }
      if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
        await showInfoDialog(
            context: context,
            title: '输入有误',
            content: 'API 接口地址必须以 http:// 或 https:// 开头');
        return;
      }
      baseUrl = normalizeBaseUrl(rawUrl);
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
          baseUrl: baseUrl,
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
        baseUrl: baseUrl,
      );
      // 若厂商支持多模态，自动配置多模态（使用默认多模态模型）
      // 自定义厂商仅支持文字识别，不配置多模态
      final multimodalConfig = !isCustom &&
              vendor.supportsMultimodal &&
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
          // 选择厂商后提供跳转开放平台按钮（获取 API Key，自定义无固定平台）
          if (_vendor != null && _vendor != AiVendor.custom)
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

          if (_vendor != null) ...[
            // 自定义厂商：Base URL + 模型名称输入
            if (_isCustom) ...[
              _SectionTitle('API 接口地址 (Base URL)'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _customBaseUrlCtrl,
                  keyboardType: TextInputType.url,
                  onChanged: (_) {
                    if (_testMessage != null) setState(_clearTestResult);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.openai.com/v1',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              _SectionTitle('模型名称'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _customModelCtrl,
                  onChanged: (_) {
                    if (_testMessage != null) setState(_clearTestResult);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: 'gpt-4o-mini',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],

            // API Key
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
                        onChanged: (_) {
                          if (_testMessage != null) setState(_clearTestResult);
                        },
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                          hintText: 'sk-...',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      // 动态显示实际生效的请求地址
                      Text(
                        '请求地址：${_requestEndpoint()}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 连通性测试
            _SectionTitle('连通性测试'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _testing ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering, size: 18),
                        label: Text(_testing ? '测试中…' : '测试连接'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '保存前建议先测试连接，确认 API 地址、Key 与模型可用',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      if (_testMessage != null) ...[
                        const SizedBox(height: 8),
                        _TestResultBanner(
                          success: _testSuccess == true,
                          message: _testMessage!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // 预设厂商：展示可选模型列表（自定义厂商无预设列表）
            if (!_isCustom) ...[
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
            ] else ...[
              _SectionTitle('说明'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '自定义配置使用 OpenAI 兼容格式，仅用于文字识别与对话。\n'
                      '图像识别请使用预设的多模态厂商（如 Kimi、通义千问）。',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ],
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
                      '· 自定义厂商需填写 Base URL 与模型名（OpenAI 兼容），仅支持文字识别\n'
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

/// 连通性测试结果横幅（成功绿色 / 失败红色）
class _TestResultBanner extends StatelessWidget {
  const _TestResultBanner({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = success ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
