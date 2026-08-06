import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// AI 请求统一超时时间
const Duration _kRequestTimeout = Duration(seconds: 20);

/// AI 模型类型
enum AiModelType {
  /// 自然语言模型（仅文本）
  text,
  /// 多模态模型（文本 + 图片）
  multimodal,
}

/// AI 模型描述
class AiModel {
  const AiModel({
    required this.id,
    required this.type,
    this.description,
  });

  /// 模型 ID（用于 API 请求）
  final String id;
  /// 模型类型
  final AiModelType type;
  /// 模型描述（可选，用于 UI 显示）
  final String? description;

  /// 是否为多模态模型
  bool get isMultimodal => type == AiModelType.multimodal;
}

/// API 请求格式
enum AiApiFormat {
  /// OpenAI 兼容格式（Kimi/DeepSeek/Qwen/Zhipu/OpenAI/Gemini）
  openai,
  /// Anthropic 原生格式（Claude）
  anthropic,
}

/// AI 模型厂商
enum AiVendor {
  kimi,
  deepseek,
  qwen, // 千问（阿里通义千问）
  zhipu, // 质谱（智谱 GLM）
  openai, // OpenAI（ChatGPT）
  google, // 谷歌 Gemini
  anthropic; // Anthropic（Claude）

  /// 厂商显示名称
  String get label {
    switch (this) {
      case AiVendor.kimi:
        return 'Kimi (月之暗面)';
      case AiVendor.deepseek:
        return 'DeepSeek (深度求索)';
      case AiVendor.qwen:
        return '通义千问 (阿里)';
      case AiVendor.zhipu:
        return '智谱 GLM';
      case AiVendor.openai:
        return 'OpenAI (ChatGPT)';
      case AiVendor.google:
        return 'Google Gemini';
      case AiVendor.anthropic:
        return 'Anthropic (Claude)';
    }
  }

  /// API 基础地址
  String get baseUrl {
    switch (this) {
      case AiVendor.kimi:
        return 'https://api.moonshot.cn/v1';
      case AiVendor.deepseek:
        return 'https://api.deepseek.com';
      case AiVendor.qwen:
        // 通义千问 OpenAI 兼容模式
        return 'https://dashscope.aliyuncs.com/compatible-mode/v1';
      case AiVendor.zhipu:
        // 智谱 GLM OpenAI 兼容接口
        return 'https://open.bigmodel.cn/api/paas/v4';
      case AiVendor.openai:
        return 'https://api.openai.com/v1';
      case AiVendor.google:
        // Gemini OpenAI 兼容端点
        return 'https://generativelanguage.googleapis.com/v1beta/openai';
      case AiVendor.anthropic:
        return 'https://api.anthropic.com/v1';
    }
  }

  /// 该厂商使用的 API 请求格式
  AiApiFormat get apiFormat {
    switch (this) {
      case AiVendor.anthropic:
        return AiApiFormat.anthropic;
      default:
        return AiApiFormat.openai;
    }
  }

  /// 该厂商是否支持 response_format JSON 输出模式
  bool get jsonMode => this == AiVendor.deepseek;

  /// 该厂商可用的模型列表（含类型信息）
  List<AiModel> get availableModels {
    switch (this) {
      case AiVendor.kimi:
        return const [
          AiModel(id: 'kimi-k2.5', type: AiModelType.multimodal, description: '多模态'),
          AiModel(id: 'kimi-k2-thinking', type: AiModelType.text, description: '思考'),
          AiModel(id: 'moonshot-v1-8k', type: AiModelType.text, description: '8k 上下文'),
          AiModel(id: 'moonshot-v1-32k', type: AiModelType.text, description: '32k 上下文'),
          AiModel(id: 'moonshot-v1-128k', type: AiModelType.text, description: '128k 上下文'),
        ];
      case AiVendor.deepseek:
        return const [
          AiModel(id: 'deepseek-v4-pro', type: AiModelType.text, description: '思考'),
          AiModel(id: 'deepseek-v4-flash', type: AiModelType.text, description: '快捷'),
        ];
      case AiVendor.qwen:
        return const [
          AiModel(id: 'qwen-max', type: AiModelType.text, description: '最强'),
          AiModel(id: 'qwen-plus', type: AiModelType.text, description: '均衡'),
          AiModel(id: 'qwen-turbo', type: AiModelType.text, description: '快捷'),
          AiModel(id: 'qwen-vl-max', type: AiModelType.multimodal, description: '多模态最强'),
          AiModel(id: 'qwen-vl-plus', type: AiModelType.multimodal, description: '多模态'),
        ];
      case AiVendor.zhipu:
        return const [
          AiModel(id: 'glm-4', type: AiModelType.text, description: '旗舰'),
          AiModel(id: 'glm-4-flash', type: AiModelType.text, description: '快捷'),
          AiModel(id: 'glm-4v', type: AiModelType.multimodal, description: '多模态'),
        ];
      case AiVendor.openai:
        return const [
          AiModel(id: 'gpt-4o', type: AiModelType.multimodal, description: '旗舰多模态'),
          AiModel(id: 'gpt-4o-mini', type: AiModelType.multimodal, description: '轻量多模态'),
          AiModel(id: 'gpt-4-turbo', type: AiModelType.multimodal, description: '增强'),
        ];
      case AiVendor.google:
        return const [
          AiModel(id: 'gemini-2.0-flash', type: AiModelType.multimodal, description: '最新多模态'),
          AiModel(id: 'gemini-1.5-pro', type: AiModelType.multimodal, description: 'Pro 多模态'),
          AiModel(id: 'gemini-1.5-flash', type: AiModelType.multimodal, description: '轻量多模态'),
        ];
      case AiVendor.anthropic:
        return const [
          AiModel(id: 'claude-3-5-sonnet-20241022', type: AiModelType.multimodal, description: '旗舰多模态'),
          AiModel(id: 'claude-3-5-haiku-20241022', type: AiModelType.multimodal, description: '轻量多模态'),
          AiModel(id: 'claude-3-opus-20240229', type: AiModelType.multimodal, description: 'Opus 多模态'),
        ];
    }
  }

  /// 该厂商的所有多模态模型 ID（用于图片识别选择）
  List<String> get multimodalModelIds =>
      availableModels.where((m) => m.isMultimodal).map((m) => m.id).toList();

  /// 该厂商的所有模型 ID（用于文字识别选择，多模态模型也可用于文字）
  List<String> get allModelIds =>
      availableModels.map((m) => m.id).toList();

  /// 该厂商是否支持多模态（图片输入）
  bool get supportsMultimodal => multimodalModelIds.isNotEmpty;

  /// 厂商创建 API Key 的帮助链接
  String get helpUrl {
    switch (this) {
      case AiVendor.kimi:
        return 'https://platform.moonshot.cn';
      case AiVendor.deepseek:
        return 'https://platform.deepseek.com';
      case AiVendor.qwen:
        return 'https://dashscope.console.aliyun.com';
      case AiVendor.zhipu:
        return 'https://open.bigmodel.cn';
      case AiVendor.openai:
        return 'https://platform.openai.com';
      case AiVendor.google:
        return 'https://aistudio.google.com';
      case AiVendor.anthropic:
        return 'https://console.anthropic.com';
    }
  }
}

/// 单个模型配置（厂商 + API Key + 模型 ID）
///
/// 文本识别和多模态识别各自独立配置，可使用不同厂商。
/// 例如：文本用 DeepSeek，多模态用 Kimi。
class AiModelConfig {
  const AiModelConfig({
    required this.vendor,
    required this.apiKey,
    required this.modelId,
  });

  final AiVendor vendor;
  final String apiKey;
  final String modelId;

  bool get isValid => apiKey.isNotEmpty && modelId.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'vendor': vendor.name,
        'apiKey': apiKey,
        'modelId': modelId,
      };

  factory AiModelConfig.fromMap(Map<String, dynamic> map) => AiModelConfig(
        vendor: AiVendor.values.firstWhere(
          (e) => e.name == map['vendor'],
          orElse: () => AiVendor.kimi,
        ),
        apiKey: map['apiKey'] as String? ?? '',
        modelId: map['modelId'] as String? ?? '',
      );
}

/// AI 配置（Profile）
///
/// 将文本识别配置和多模态识别配置打包为一个完整配置。
/// 用户可创建多个配置并在不同配置间切换。
/// 文本和多模态可分别使用不同厂商的模型。
class AiProfile {
  const AiProfile({
    required this.id,
    required this.name,
    this.textConfig,
    this.multimodalConfig,
  });

  /// 唯一标识
  final String id;
  /// 配置名称（如"我的配置"）
  final String name;
  /// 文本识别配置（厂商 + API Key + 模型）
  final AiModelConfig? textConfig;
  /// 多模态识别配置（厂商 + API Key + 模型），可选
  final AiModelConfig? multimodalConfig;

  /// 是否有可用的文本模型
  bool get hasTextModel =>
      textConfig != null && textConfig!.modelId.isNotEmpty;

  /// 是否有可用的多模态模型
  bool get hasMultimodalModel =>
      multimodalConfig != null && multimodalConfig!.modelId.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'textConfig': textConfig?.toMap(),
        'multimodalConfig': multimodalConfig?.toMap(),
      };

  factory AiProfile.fromMap(Map<String, dynamic> map) => AiProfile(
        id: map['id'] as String,
        name: map['name'] as String,
        textConfig: map['textConfig'] != null
            ? AiModelConfig.fromMap(map['textConfig'] as Map<String, dynamic>)
            : null,
        multimodalConfig: map['multimodalConfig'] != null
            ? AiModelConfig.fromMap(
                map['multimodalConfig'] as Map<String, dynamic>)
            : null,
      );
}

/// AI 识别结果
class AiRecognitionResult {
  const AiRecognitionResult({
    required this.amount,
    required this.type,
    required this.category,
    this.note,
  });

  final double amount;
  final String type; // 'income' / 'expense'
  final String category;
  final String? note;
}

/// AI 对话消息
///
/// 用于对话模式，记录用户和 AI 的多轮交互。
/// 用户消息可附带多张图片；AI 消息可附带识别结果供用户保存。
class AiChatMessage {
  const AiChatMessage({
    required this.role,
    this.text,
    this.base64Images = const [],
    this.results = const [],
    this.time,
    this.saved = false,
  });

  /// 角色：system / user / assistant
  final String role;

  /// 文本内容
  final String? text;

  /// 用户消息附带的 base64 图片列表
  final List<String> base64Images;

  /// AI 消息中解析出的可保存识别结果
  final List<AiRecognitionResult> results;

  /// 消息时间
  final DateTime? time;

  /// 识别结果是否已保存到账单
  final bool saved;

  /// 是否为用户消息
  bool get isUser => role == 'user';

  /// 是否为 AI 消息
  bool get isAssistant => role == 'assistant';

  AiChatMessage copyWith({
    String? role,
    String? text,
    List<String>? base64Images,
    List<AiRecognitionResult>? results,
    DateTime? time,
    bool? saved,
  }) =>
      AiChatMessage(
        role: role ?? this.role,
        text: text ?? this.text,
        base64Images: base64Images ?? this.base64Images,
        results: results ?? this.results,
        time: time ?? this.time,
        saved: saved ?? this.saved,
      );
}

/// AI 对话响应
class AiChatResponse {
  const AiChatResponse({
    this.text,
    this.results = const [],
  });

  final String? text;
  final List<AiRecognitionResult> results;
}

/// AI 服务
///
/// 管理多个 AI 配置（Profile），调用大模型 API 进行记账识别。
/// 支持为文字识别和图像识别分别选择 Profile 和具体模型 ID。
/// 所有 Profile 相关存储均按 userId 隔离，避免多账号之间互相看到对方的 AI 配置。
class AiService {
  // Profile 存储 key 均为全局前缀，实际使用时拼接 userId 组成用户维度 key
  static const _kProfiles = 'ai_profiles';
  static const _kActiveTextProfileId = 'ai_active_text_profile_id';
  static const _kActiveMultimodalProfileId = 'ai_active_multimodal_profile_id';
  // 用户可在同一 Profile 下切换具体模型 ID（覆盖 profile.textConfig/multimodalConfig.modelId）
  static const _kActiveTextModelId = 'ai_active_text_model_id';
  static const _kActiveMultimodalModelId = 'ai_active_multimodal_model_id';

  /// 拼接用户维度的存储 key，如 ai_profiles_1
  String _userKey(String baseKey, int userId) => '${baseKey}_$userId';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 获取指定用户的所有配置
  Future<List<AiProfile>> getProfiles(int userId) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_userKey(_kProfiles, userId));
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => AiProfile.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveProfiles(int userId, List<AiProfile> profiles) async {
    final prefs = await _getPrefs();
    final raw = jsonEncode(profiles.map((p) => p.toMap()).toList());
    await prefs.setString(_userKey(_kProfiles, userId), raw);
  }

  /// 添加配置
  Future<void> addProfile(int userId, AiProfile profile) async {
    // getProfiles 可能返回 const []（不可修改），需创建可修改副本
    final profiles = List<AiProfile>.from(await getProfiles(userId));
    profiles.add(profile);
    await _saveProfiles(userId, profiles);
  }

  /// 更新配置
  Future<void> updateProfile(int userId, AiProfile profile) async {
    final profiles = List<AiProfile>.from(await getProfiles(userId));
    final idx = profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      profiles[idx] = profile;
      await _saveProfiles(userId, profiles);
    }
  }

  /// 删除配置
  Future<void> removeProfile(int userId, String id) async {
    final profiles = List<AiProfile>.from(await getProfiles(userId));
    profiles.removeWhere((p) => p.id == id);
    await _saveProfiles(userId, profiles);
    // 如果删除的是当前激活的，清除激活状态（并切到第一个可用配置）
    final activeTextId = await getActiveTextProfileId(userId);
    if (activeTextId == id) {
      final newId = profiles.isEmpty ? null : profiles.first.id;
      await setActiveTextProfileId(userId, newId);
      // 切换 Profile 时清除模型 ID 覆盖，让调用方回退到 Profile 默认模型
      await setActiveTextModelId(userId, null);
    }
    final activeMmId = await getActiveMultimodalProfileId(userId);
    if (activeMmId == id) {
      final newId = profiles.isEmpty ? null : profiles.first.id;
      await setActiveMultimodalProfileId(userId, newId);
      await setActiveMultimodalModelId(userId, null);
    }
  }

  /// 获取指定用户文字识别激活的配置 ID
  Future<String?> getActiveTextProfileId(int userId) async {
    final prefs = await _getPrefs();
    return prefs.getString(_userKey(_kActiveTextProfileId, userId));
  }

  Future<void> setActiveTextProfileId(int userId, String? id) async {
    final prefs = await _getPrefs();
    final key = _userKey(_kActiveTextProfileId, userId);
    if (id == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, id);
    }
  }

  /// 获取指定用户图像识别激活的配置 ID
  Future<String?> getActiveMultimodalProfileId(int userId) async {
    final prefs = await _getPrefs();
    return prefs.getString(_userKey(_kActiveMultimodalProfileId, userId));
  }

  Future<void> setActiveMultimodalProfileId(int userId, String? id) async {
    final prefs = await _getPrefs();
    final key = _userKey(_kActiveMultimodalProfileId, userId);
    if (id == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, id);
    }
  }

  /// 获取指定用户文字识别当前选中的模型 ID（覆盖 Profile 默认）
  /// 若未设置，返回 null，调用方应回退到 Profile.textConfig.modelId
  Future<String?> getActiveTextModelId(int userId) async {
    final prefs = await _getPrefs();
    return prefs.getString(_userKey(_kActiveTextModelId, userId));
  }

  Future<void> setActiveTextModelId(int userId, String? id) async {
    final prefs = await _getPrefs();
    final key = _userKey(_kActiveTextModelId, userId);
    if (id == null || id.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, id);
    }
  }

  /// 获取指定用户图像识别当前选中的模型 ID（覆盖 Profile 默认）
  Future<String?> getActiveMultimodalModelId(int userId) async {
    final prefs = await _getPrefs();
    return prefs.getString(_userKey(_kActiveMultimodalModelId, userId));
  }

  Future<void> setActiveMultimodalModelId(int userId, String? id) async {
    final prefs = await _getPrefs();
    final key = _userKey(_kActiveMultimodalModelId, userId);
    if (id == null || id.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, id);
    }
  }

  /// 构建 HTTP 请求头
  Map<String, String> _buildHeaders(AiVendor vendor, String apiKey) {
    if (vendor.apiFormat == AiApiFormat.anthropic) {
      return {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      };
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  /// 构建 API 端点 URL
  String _buildEndpoint(AiVendor vendor) {
    if (vendor.apiFormat == AiApiFormat.anthropic) {
      return '${vendor.baseUrl}/messages';
    }
    return '${vendor.baseUrl}/chat/completions';
  }

  /// 从响应中提取文本内容
  String _extractContent(AiVendor vendor, Map<String, dynamic> data) {
    if (vendor.apiFormat == AiApiFormat.anthropic) {
      // Anthropic: {content: [{type: 'text', text: '...'}]}
      final content = data['content'] as List;
      return content.first['text'] as String;
    }
    // OpenAI: {choices: [{message: {content: '...'}}]}
    final choices = data['choices'] as List;
    return choices.first['message']['content'] as String;
  }

  /// 发送 HTTP POST 请求，统一处理超时、网络错误与状态码检查
  ///
  /// [timeoutMessage] 超时时的提示文案；
  /// [networkPrefix] 网络错误提示前缀（拼接为「$networkPrefix网络请求失败：$e」）；
  /// [statusPrefix] 状态码非 200 时的错误前缀（拼接为「${statusPrefix}（code）：body」）。
  Future<http.Response> _post({
    required AiModelConfig config,
    required String url,
    required Map<String, dynamic> body,
    required String timeoutMessage,
    required String statusPrefix,
    String networkPrefix = '',
  }) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse(url),
        headers: _buildHeaders(config.vendor, config.apiKey),
        body: jsonEncode(body),
      ).timeout(_kRequestTimeout);
    } on TimeoutException {
      throw AiException(timeoutMessage);
    } catch (e) {
      throw AiException('$networkPrefix网络请求失败：$e');
    }

    if (response.statusCode != 200) {
      throw AiException('$statusPrefix（${response.statusCode}）：${response.body}');
    }
    return response;
  }

  /// 执行带重试的 AI 识别请求（最多 3 次）
  ///
  /// [buildBody] 每次尝试都会重新构造请求体（不同厂商格式不同）。
  /// 解析失败时延迟 500ms 重试；第 3 次仍失败则抛出异常。
  Future<AiRecognitionResult> _recognizeWithRetry({
    required AiModelConfig config,
    required String url,
    required Map<String, dynamic> Function() buildBody,
    required List<String> validCategories,
  }) async {
    // 最多重试 3 次
    for (var attempt = 1; attempt <= 3; attempt++) {
      final response = await _post(
        config: config,
        url: url,
        body: buildBody(),
        timeoutMessage: 'API 请求超时（20s），请检查网络或代理设置',
        statusPrefix: 'API 请求失败',
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = _extractContent(config.vendor, data);
      try {
        return _parseResult(content, validCategories: validCategories);
      } catch (e) {
        // 解析失败，如果是最后一次尝试，抛出异常
        if (attempt == 3) {
          throw AiException('AI 返回结果无法解析（已重试 3 次）：$content');
        }
        // 否则继续重试
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    // 逻辑上不会到达
    throw const AiException('AI 识别失败');
  }

  /// 验证 API Key 是否有效
  ///
  /// 发送一个最小化的测试请求，根据响应判断 API Key 是否正确。
  /// 验证失败时抛出 [AiException]，包含具体错误信息和解决建议。
  Future<void> verifyApiKey({
    required AiVendor vendor,
    required String apiKey,
    required String modelId,
  }) async {
    // 去除前后空格（用户粘贴时可能带入空白字符）
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw const AiException('API Key 不能为空\n\n解决方法：请输入有效的 API Key');
    }

    final url = _buildEndpoint(vendor);
    final body = <String, dynamic>{
      'model': modelId,
      'messages': [
        {'role': 'user', 'content': 'hi'},
      ],
      'max_tokens': 5,
    };
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse(url),
        headers: _buildHeaders(vendor, trimmedKey),
        body: jsonEncode(body),
      ).timeout(_kRequestTimeout);
    } on TimeoutException {
      throw AiException(
          'API 验证请求超时（20 秒）\n\n'
          '可能原因：\n'
          '· 网络连接不稳定或无法访问 API 服务器\n'
          '· 模拟器/设备未联网或 DNS 解析慢\n\n'
          '解决方法：\n'
          '· 检查网络连接\n'
          '· 确认设备能访问 ${vendor.baseUrl}');
    } catch (e) {
      throw AiException(
          '网络请求失败：$e\n\n'
          '解决方法：\n'
          '· 检查网络连接\n'
          '· 确认 API 地址 ${vendor.baseUrl} 可访问');
    }

    if (response.statusCode == 401) {
      throw const AiException(
          'API Key 无效或未授权（401）\n\n'
          '解决方法：\n'
          '· 检查 API Key 是否正确复制（无多余空格/换行）\n'
          '· 确认 API Key 未过期或被禁用\n'
          '· 重新生成 API Key');
    }
    if (response.statusCode == 403) {
      throw const AiException(
          'API Key 无访问权限（403）\n\n'
          '解决方法：\n'
          '· 确认账号已实名认证\n'
          '· 确认 API Key 有访问该模型的权限\n'
          '· 确认账户余额充足');
    }
    if (response.statusCode == 404) {
      throw AiException(
          '模型不存在或路径错误（404）\n\n'
          '解决方法：\n'
          '· 检查模型 ID「$modelId」是否正确\n'
          '· 确认厂商 ${vendor.label} 支持该模型');
    }
    if (response.statusCode == 429) {
      throw const AiException(
          '请求频率过高或余额不足（429）\n\n'
          '解决方法：\n'
          '· 稍后重试\n'
          '· 检查账户余额是否充足\n'
          '· 确认未触发 RPM 限制');
    }
    if (response.statusCode != 200) {
      // 提取错误消息（兼容 OpenAI 和 Anthropic 错误格式）
      String detail = response.body;
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final err = data['error'];
        if (err is Map && err['message'] != null) {
          detail = err['message'].toString();
        }
      } catch (_) {
        // 保持原始 body
      }
      throw AiException(
          'API 验证失败（${response.statusCode}）：$detail\n\n'
          '解决方法：\n'
          '· 查看上方错误详情\n'
          '· 如无法解决，请复制完整错误联系开发者');
    }
    // 200 表示 API Key 有效
  }

  /// 调用 AI 识别记账信息（纯文本）
  /// [config] 由调用方构造（vendor + apiKey + modelId），
  /// 这样可在同一 Profile 下切换不同模型 ID。
  /// 自动兼容 OpenAI 和 Anthropic 两种 API 格式。
  /// 解析失败时自动重试，最多 3 次
  Future<AiRecognitionResult> recognizeFromText({
    required AiModelConfig config,
    required String text,
    required List<String> expenseCategories,
    required List<String> incomeCategories,
  }) async {
    if (config.apiKey.isEmpty) {
      throw const AiException('未配置文本识别');
    }
    if (config.modelId.isEmpty) {
      throw const AiException('未配置文本识别模型');
    }

    final prompt = _buildPrompt(expenseCategories, incomeCategories);
    final url = _buildEndpoint(config.vendor);
    final isAnthropic = config.vendor.apiFormat == AiApiFormat.anthropic;
    // DeepSeek 支持 response_format JSON Output
    final useJsonMode = config.vendor.jsonMode;

    return _recognizeWithRetry(
      config: config,
      url: url,
      validCategories: [...expenseCategories, ...incomeCategories],
      buildBody: () {
        final body = <String, dynamic>{
          'model': config.modelId,
          'max_tokens': 1024,
          // 不传 temperature，让 API 用默认值（某些思考模型只允许 1）
        };

        if (isAnthropic) {
          // Anthropic: system 作为顶层字段，messages 仅含 user
          body['system'] = prompt;
          body['messages'] = [
            {'role': 'user', 'content': text},
          ];
        } else {
          // OpenAI 格式: system 作为 message
          body['messages'] = [
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': text},
          ];
        }
        if (useJsonMode) {
          body['response_format'] = {'type': 'json_object'};
        }
        return body;
      },
    );
  }

  /// 调用 AI 识别记账信息（图片 + 文本）
  /// [config] 由调用方构造（vendor + apiKey + modelId），
  /// 这样可在同一 Profile 下切换不同多模态模型 ID。
  /// 自动兼容 OpenAI 和 Anthropic 两种 API 格式。
  /// 解析失败时自动重试，最多 3 次
  Future<AiRecognitionResult> recognizeFromImage({
    required AiModelConfig config,
    required String base64Image,
    String? textHint,
    required List<String> expenseCategories,
    required List<String> incomeCategories,
  }) async {
    if (config.apiKey.isEmpty) {
      throw const AiException('未配置多模态识别');
    }
    if (config.modelId.isEmpty) {
      throw const AiException('未配置多模态识别模型');
    }
    if (!config.vendor.supportsMultimodal) {
      throw const AiException('多模态识别厂商不支持图片输入');
    }

    final prompt = _buildPrompt(expenseCategories, incomeCategories);
    final url = _buildEndpoint(config.vendor);
    final isAnthropic = config.vendor.apiFormat == AiApiFormat.anthropic;

    return _recognizeWithRetry(
      config: config,
      url: url,
      validCategories: [...expenseCategories, ...incomeCategories],
      buildBody: () {
        final Map<String, dynamic> body;
        if (isAnthropic) {
          // Anthropic: system 顶层字段，图片用 source 结构
          final content = <Map<String, dynamic>>[
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': base64Image,
              },
            },
            if (textHint != null && textHint.isNotEmpty)
              {'type': 'text', 'text': textHint},
          ];
          body = {
            'model': config.modelId,
            'max_tokens': 1024,
            'system': prompt,
            'messages': [
              {'role': 'user', 'content': content},
            ],
          };
        } else {
          // OpenAI 格式: prompt 作为 text 内容块，图片用 image_url
          final content = <Map<String, dynamic>>[
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
            },
            if (textHint != null && textHint.isNotEmpty)
              {'type': 'text', 'text': textHint},
          ];
          body = {
            'model': config.modelId,
            'max_tokens': 1024,
            'messages': [
              {'role': 'user', 'content': content},
            ],
          };
        }
        return body;
      },
    );
  }

  /// AI 对话模式
  ///
  /// 支持多轮文字 + 图片对话。根据最新消息是否含图选择文本或多模态配置。
  /// AI 回复会优先尝试解析为 JSON 账单数组；解析失败则视为普通文本回复。
  Future<AiChatResponse> chat({
    required AiModelConfig config,
    required List<AiChatMessage> history,
    required AiChatMessage userMessage,
    required List<String> expenseCategories,
    required List<String> incomeCategories,
  }) async {
    if (config.apiKey.isEmpty) {
      throw const AiException('未配置 AI 对话');
    }
    if (config.modelId.isEmpty) {
      throw const AiException('未配置 AI 对话模型');
    }

    final prompt = _buildChatPrompt(expenseCategories, incomeCategories);
    final url = _buildEndpoint(config.vendor);
    final isAnthropic = config.vendor.apiFormat == AiApiFormat.anthropic;

    // 构造消息列表：system 提示词 + 历史消息 + 当前用户消息
    final messages = <Map<String, dynamic>>[];

    void addMessage(AiChatMessage msg) {
      if (msg.isUser) {
        if (isAnthropic) {
          // Anthropic: 图片放在 content 数组中
          final content = <Map<String, dynamic>>[];
          for (final img in msg.base64Images) {
            content.add({
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': img,
              },
            });
          }
          if (msg.text != null && msg.text!.isNotEmpty) {
            content.add({'type': 'text', 'text': msg.text!});
          }
          messages.add({'role': 'user', 'content': content});
        } else {
          // OpenAI 格式：content 数组支持 text + image_url
          final content = <Map<String, dynamic>>[];
          if (msg.text != null && msg.text!.isNotEmpty) {
            content.add({'type': 'text', 'text': msg.text!});
          }
          for (final img in msg.base64Images) {
            content.add({
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$img'},
            });
          }
          messages.add({'role': 'user', 'content': content});
        }
      } else if (msg.isAssistant) {
        if (msg.text != null && msg.text!.isNotEmpty) {
          messages.add({'role': 'assistant', 'content': msg.text});
        }
      }
    }

    // 添加历史消息（仅保留最近 10 条，避免上下文过长）
    final recentHistory = history.length > 10 ? history.sublist(history.length - 10) : history;
    for (final msg in recentHistory) {
      addMessage(msg);
    }
    addMessage(userMessage);

    final body = <String, dynamic>{
      'model': config.modelId,
      'max_tokens': 1024,
    };
    if (isAnthropic) {
      // Anthropic: system 作为顶层字段
      body['system'] = prompt;
      body['messages'] = messages;
    } else {
      // OpenAI 格式：system 作为第一条消息
      body['messages'] = [
        {'role': 'system', 'content': prompt},
        ...messages,
      ];
    }

    final response = await _post(
      config: config,
      url: url,
      body: body,
      timeoutMessage: 'AI 对话请求超时（20s），请检查网络或代理设置',
      statusPrefix: 'AI 对话请求失败',
      networkPrefix: 'AI 对话',
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = _extractContent(config.vendor, data);

    // 尝试从回复中解析账单结果
    final validCategories = [...expenseCategories, ...incomeCategories];
    final results = _parseChatResults(content, validCategories: validCategories);

    // 如果解析到账单，把账单从文本中移除，剩余部分作为自然语言回复
    String? textReply;
    if (results.isNotEmpty) {
      textReply = _removeJsonBlock(content);
      if (textReply.trim().isEmpty) textReply = null;
    } else {
      textReply = content.trim();
    }

    return AiChatResponse(
      text: textReply,
      results: results,
    );
  }

  /// 从 AI 对话回复中解析账单结果
  ///
  /// 支持两种形式：
  /// 1. 直接返回单条 JSON 对象
  /// 2. 返回 {"bills": [...]} 数组
  List<AiRecognitionResult> _parseChatResults(
    String content, {
    required List<String> validCategories,
  }) {
    final results = <AiRecognitionResult>[];

    // 优先匹配 ```json ... ``` 或 ``` ... ``` 包裹的 JSON
    final jsonStr = content.trim();
    if (jsonStr.contains('```')) {
      final matches = RegExp(r'```(?:json)?\s*([\s\S]*?)```').allMatches(jsonStr);
      for (final match in matches) {
        final block = match.group(1)?.trim() ?? '';
        results.addAll(_tryDecodeMap(block, validCategories));
      }
    }

    if (results.isNotEmpty) return results;

    // 没有 markdown block，尝试整个内容是否就是 JSON
    results.addAll(_tryDecodeMap(jsonStr, validCategories));

    return results;
  }

  /// 尝试把字符串解码为账单，支持 {"bills": [...]} 数组与单条对象两种形式
  ///
  /// 解码失败或内容不是账单 JSON 时返回空列表（忽略该内容）。
  List<AiRecognitionResult> _tryDecodeMap(
    String jsonStr,
    List<String> validCategories,
  ) {
    final results = <AiRecognitionResult>[];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('bills')) {
          final bills = decoded['bills'] as List;
          for (final bill in bills) {
            results.add(_parseSingleResult(bill as Map<String, dynamic>, validCategories));
          }
        } else {
          results.add(_parseSingleResult(decoded, validCategories));
        }
      }
    } catch (_) {
      // 该内容不是有效账单 JSON，忽略
    }
    return results;
  }

  AiRecognitionResult _parseSingleResult(
    Map<String, dynamic> map,
    List<String> validCategories,
  ) {
    return _parseMap(map, validCategories);
  }

  /// 移除回复中的 JSON 代码块，保留自然语言部分
  String _removeJsonBlock(String content) {
    return content.replaceAllMapped(
      RegExp(r'```(?:json)?\s*[\s\S]*?```'),
      (_) => '',
    ).trim();
  }

  String _buildChatPrompt(
    List<String> expenseCategories,
    List<String> incomeCategories,
  ) {
    return '''你是 Anticount 的记账助手，正在与用户进行多轮对话。

任务：
1. 如果用户提供的信息足够记账，请返回账单 JSON，并可用自然语言简要确认。
2. 如果信息不足（缺少金额、类型、分类等），请用自然语言追问，不要返回 JSON。
3. 你可以根据上下文理解用户说的“昨天”“上周三”等相对时间。

当需要返回账单时，请使用以下 JSON 格式（可包裹在 ```json 代码块中）：
{
  "bills": [
    {
      "amount": 35.5,
      "type": "expense",
      "category": "餐饮",
      "note": "午餐"
    }
  ]
}

字段约定：
1. "amount" 必须是正数（number 类型）
2. "type" 必须是 "income" 或 "expense"
3. "category" 必须从下方分类列表中选择，不能编造
4. "note" 可选，没有则传空字符串

支出可选分类：${expenseCategories.join('、')}
收入可选分类：${incomeCategories.join('、')}

规则：
1. 追问时只返回自然语言，不要返回 JSON。
2. 返回账单时也可以附带简短自然语言说明。''';
  }

  String _buildPrompt(
    List<String> expenseCategories,
    List<String> incomeCategories,
  ) {
    return '''你是一个记账助手。请根据用户输入识别记账信息，并以 JSON 格式返回结果。

返回格式（严格 JSON，禁止任何额外文字、解释或 markdown 代码块）：
{
  "amount": 35.5,
  "type": "expense",
  "category": "餐饮",
  "note": "午餐"
}

字段约定（必须严格遵守，否则视为解析失败）：
1. "amount" 必须是正数（number 类型，不能是字符串），如 35.5
2. "type" 必须是字符串 "income" 或 "expense" 之一，不能是其他值
3. "category" 必须从下方分类列表中选择，不能编造新分类
4. "note" 是字符串，可选；如无备注返回空字符串 ""

支出可选分类：${expenseCategories.join('、')}
收入可选分类：${incomeCategories.join('、')}

规则：
1. 根据 type 选择对应分类：type=income 时从收入分类选，type=expense 时从支出分类选
2. 如无法确定分类，使用"其他"（如分类列表中存在）
3. amount 必须为正数；如输入为"收入 100"则 type=income，amount=100
4. 仅返回 JSON 对象，不要包裹在 markdown 代码块中''';
  }

  /// 校验字段并构建识别结果（amount>0、type、category 白名单）
  ///
  /// [errorSuffix] 追加到校验错误信息末尾（如原始内容），便于排查。
  AiRecognitionResult _parseMap(
    Map<String, dynamic> map,
    List<String> validCategories, {
    String errorSuffix = '',
  }) {
    // amount 必须是正数
    final rawAmount = map['amount'];
    if (rawAmount == null) {
      throw AiException('缺少 amount 字段$errorSuffix');
    }
    final amount = (rawAmount as num).toDouble();
    if (amount <= 0) {
      throw AiException('amount 必须为正数$errorSuffix');
    }

    // type 必须是 income 或 expense
    final type = (map['type'] as String?)?.toLowerCase();
    if (type != 'income' && type != 'expense') {
      throw AiException('type 字段无效$errorSuffix');
    }

    // category 必须在分类列表中
    final category = (map['category'] as String?) ?? '';
    if (category.isEmpty || !validCategories.contains(category)) {
      throw AiException('category 不在分类列表中$errorSuffix');
    }

    final note = map['note'] as String?;
    return AiRecognitionResult(
      amount: amount,
      type: type == 'income' ? 'income' : 'expense',
      category: category,
      note: note,
    );
  }

  /// 解析识别请求的返回内容（自动剥离 markdown 代码块）
  ///
  /// 校验失败时错误信息附带上文，便于排查 AI 原始输出。
  AiRecognitionResult _parseResult(
    String content, {
    required List<String> validCategories,
  }) {
    var jsonStr = content.trim();
    if (jsonStr.contains('```')) {
      final match = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
      if (match != null) {
        jsonStr = match.group(1)!.trim();
      }
    }

    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return _parseMap(map, validCategories, errorSuffix: ': $content');
  }
}

/// AI 异常
class AiException implements Exception {
  const AiException(this.message);
  final String message;

  @override
  String toString() => message;
}
