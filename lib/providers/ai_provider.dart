import 'package:flutter/foundation.dart';

import '../services/ai_service.dart';

/// AI 配置与识别状态
///
/// 管理多个 AI Profile，支持增删改查。
/// 文字识别和图像识别可分别选择不同的 Profile 及具体模型 ID。
/// 模型 ID 可在同一 Profile 下切换（覆盖 Profile 默认 modelId）。
class AiProvider extends ChangeNotifier {
  AiProvider(this._service);

  final AiService _service;

  List<AiProfile> _profiles = const [];
  String? _activeTextProfileId;
  String? _activeMultimodalProfileId;
  // 当前选中的模型 ID（覆盖 Profile 默认）。为 null 时使用 Profile 默认模型。
  String? _activeTextModelId;
  String? _activeMultimodalModelId;

  /// 对话模式历史消息
  final List<AiChatMessage> _chatHistory = [];

  List<AiProfile> get profiles => _profiles;

  /// 当前对话历史（不可变副本）
  List<AiChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  /// 文字识别当前激活的配置
  AiProfile? get activeTextProfile {
    if (_activeTextProfileId == null) return null;
    if (_profiles.isEmpty) return null;
    return _profiles.firstWhere(
      (p) => p.id == _activeTextProfileId,
      orElse: () => _profiles.first,
    );
  }

  /// 图像识别当前激活的配置
  AiProfile? get activeMultimodalProfile {
    if (_activeMultimodalProfileId == null) return null;
    if (_profiles.isEmpty) return null;
    return _profiles.firstWhere(
      (p) => p.id == _activeMultimodalProfileId,
      orElse: () => _profiles.first,
    );
  }

  /// 文字识别当前选中的模型 ID（若为 null，则使用 Profile 默认）
  String? get activeTextModelId => _activeTextModelId;
  String? get activeMultimodalModelId => _activeMultimodalModelId;

  /// 文字识别实际生效的配置（vendor + apiKey 来自 Profile，modelId 可被覆盖）
  AiModelConfig? get effectiveTextConfig {
    final profile = activeTextProfile;
    if (profile == null || profile.textConfig == null) return null;
    final base = profile.textConfig!;
    final modelId = _activeTextModelId ?? base.modelId;
    return AiModelConfig(
      vendor: base.vendor,
      apiKey: base.apiKey,
      modelId: modelId,
    );
  }

  /// 图像识别实际生效的配置（vendor + apiKey 来自 Profile，modelId 可被覆盖）
  AiModelConfig? get effectiveMultimodalConfig {
    final profile = activeMultimodalProfile;
    if (profile == null || profile.multimodalConfig == null) return null;
    final base = profile.multimodalConfig!;
    final modelId = _activeMultimodalModelId ?? base.modelId;
    return AiModelConfig(
      vendor: base.vendor,
      apiKey: base.apiKey,
      modelId: modelId,
    );
  }

  /// 是否有可用的文字识别配置
  bool get hasAvailableProfile => effectiveTextConfig?.isValid ?? false;

  /// 是否有可用的图像识别配置
  bool get supportsMultimodal =>
      effectiveMultimodalConfig != null &&
      effectiveMultimodalConfig!.vendor.supportsMultimodal &&
      effectiveMultimodalConfig!.isValid;

  /// 启动时加载配置
  Future<void> bootstrap() async {
    _profiles = await _service.getProfiles();
    _activeTextProfileId = await _service.getActiveTextProfileId();
    _activeMultimodalProfileId = await _service.getActiveMultimodalProfileId();
    _activeTextModelId = await _service.getActiveTextModelId();
    _activeMultimodalModelId = await _service.getActiveMultimodalModelId();
    notifyListeners();
  }

  /// 添加配置
  Future<void> addProfile(AiProfile profile) async {
    await _service.addProfile(profile);
    _profiles = await _service.getProfiles();
    // 如果是第一个配置，自动激活文字识别
    if (_profiles.length == 1) {
      _activeTextProfileId = profile.id;
      _activeTextModelId = profile.textConfig?.modelId;
      await _service.setActiveTextProfileId(profile.id);
      await _service.setActiveTextModelId(_activeTextModelId);
      // 如果该配置有多模态，也自动激活图像识别
      if (profile.hasMultimodalModel) {
        _activeMultimodalProfileId = profile.id;
        _activeMultimodalModelId = profile.multimodalConfig?.modelId;
        await _service.setActiveMultimodalProfileId(profile.id);
        await _service.setActiveMultimodalModelId(_activeMultimodalModelId);
      }
    }
    notifyListeners();
  }

  /// 更新配置
  Future<void> updateProfile(AiProfile profile) async {
    await _service.updateProfile(profile);
    _profiles = await _service.getProfiles();
    // 如果当前激活的 Profile 被更新，同步刷新模型 ID（防止旧 modelId 失效）
    if (_activeTextProfileId == profile.id) {
      final newModelId = profile.textConfig?.modelId;
      // 若当前选中的模型 ID 不在新厂商的可用模型中，则重置为默认
      if (newModelId == null ||
          (_activeTextModelId != null &&
              !profile.textConfig!.vendor.allModelIds
                  .contains(_activeTextModelId))) {
        _activeTextModelId = newModelId;
        await _service.setActiveTextModelId(newModelId);
      }
    }
    if (_activeMultimodalProfileId == profile.id) {
      final newModelId = profile.multimodalConfig?.modelId;
      if (newModelId == null ||
          (_activeMultimodalModelId != null &&
              !profile.multimodalConfig!.vendor.multimodalModelIds
                  .contains(_activeMultimodalModelId))) {
        _activeMultimodalModelId = newModelId;
        await _service.setActiveMultimodalModelId(newModelId);
      }
    }
    notifyListeners();
  }

  /// 删除配置
  Future<void> removeProfile(String id) async {
    await _service.removeProfile(id);
    _profiles = await _service.getProfiles();
    _activeTextProfileId = await _service.getActiveTextProfileId();
    _activeMultimodalProfileId =
        await _service.getActiveMultimodalProfileId();
    _activeTextModelId = await _service.getActiveTextModelId();
    _activeMultimodalModelId = await _service.getActiveMultimodalModelId();
    notifyListeners();
  }

  /// 切换文字识别 Profile（同时重置模型 ID 为 Profile 默认）
  Future<void> setActiveTextProfile(String id) async {
    await _service.setActiveTextProfileId(id);
    _activeTextProfileId = id;
    // 重置模型 ID 为 Profile 默认
    final profile =
        _profiles.firstWhere((p) => p.id == id, orElse: () => _profiles.first);
    final defaultModelId = profile.textConfig?.modelId;
    _activeTextModelId = defaultModelId;
    await _service.setActiveTextModelId(defaultModelId);
    notifyListeners();
  }

  /// 切换图像识别 Profile（同时重置模型 ID 为 Profile 默认）
  Future<void> setActiveMultimodalProfile(String id) async {
    await _service.setActiveMultimodalProfileId(id);
    _activeMultimodalProfileId = id;
    final profile =
        _profiles.firstWhere((p) => p.id == id, orElse: () => _profiles.first);
    final defaultModelId = profile.multimodalConfig?.modelId;
    _activeMultimodalModelId = defaultModelId;
    await _service.setActiveMultimodalModelId(defaultModelId);
    notifyListeners();
  }

  /// 切换文字识别的具体模型 ID（保持当前 Profile，仅覆盖 modelId）
  Future<void> setActiveTextModel(String modelId) async {
    _activeTextModelId = modelId;
    await _service.setActiveTextModelId(modelId);
    notifyListeners();
  }

  /// 切换图像识别的具体模型 ID（保持当前 Profile，仅覆盖 modelId）
  Future<void> setActiveMultimodalModel(String modelId) async {
    _activeMultimodalModelId = modelId;
    await _service.setActiveMultimodalModelId(modelId);
    notifyListeners();
  }

  /// 一次性选择文字识别的 Profile + 模型 ID
  ///
  /// 用于配置界面：用户在某个 Profile 下点击具体模型时调用。
  /// 若 Profile 与当前不同，先切换 Profile（会重置模型为默认），
  /// 再覆盖为用户选中的模型 ID。
  Future<void> selectTextModel(String profileId, String modelId) async {
    if (_activeTextProfileId != profileId) {
      await setActiveTextProfile(profileId);
    }
    await setActiveTextModel(modelId);
  }

  /// 一次性选择图像识别的 Profile + 模型 ID
  Future<void> selectMultimodalModel(String profileId, String modelId) async {
    if (_activeMultimodalProfileId != profileId) {
      await setActiveMultimodalProfile(profileId);
    }
    await setActiveMultimodalModel(modelId);
  }

  /// 文本识别（使用文字识别配置 + 当前选中的模型 ID）
  Future<AiRecognitionResult> recognizeFromText({
    required String text,
    required List<String> expenseCategories,
    required List<String> incomeCategories,
  }) async {
    final config = effectiveTextConfig;
    if (config == null || !config.isValid) {
      throw const AiException('未选择文字识别配置');
    }
    return _service.recognizeFromText(
      config: config,
      text: text,
      expenseCategories: expenseCategories,
      incomeCategories: incomeCategories,
    );
  }

  /// 图片识别（使用图像识别配置 + 当前选中的模型 ID）
  Future<AiRecognitionResult> recognizeFromImage({
    required String base64Image,
    String? textHint,
    required List<String> expenseCategories,
    required List<String> incomeCategories,
  }) async {
    final config = effectiveMultimodalConfig;
    if (config == null || !config.isValid) {
      throw const AiException('未选择图像识别配置');
    }
    return _service.recognizeFromImage(
      config: config,
      base64Image: base64Image,
      textHint: textHint,
      expenseCategories: expenseCategories,
      incomeCategories: incomeCategories,
    );
  }

  /// 发送对话消息
  ///
  /// 根据用户消息是否含图自动选择文本配置或多模态配置。
  /// 返回 AI 回复，并自动追加到 [_chatHistory]。
  Future<AiChatResponse> sendChatMessage({
    required String text,
    required List<String> base64Images,
    required List<String> expenseCategories,
    required List<String> incomeCategories,
  }) async {
    final hasImage = base64Images.isNotEmpty;
    final config = hasImage ? effectiveMultimodalConfig : effectiveTextConfig;
    if (config == null || !config.isValid) {
      throw AiException(hasImage ? '未选择图像识别配置' : '未选择文本识别配置');
    }

    final userMessage = AiChatMessage(
      role: 'user',
      text: text.isEmpty ? null : text,
      base64Images: base64Images,
      time: DateTime.now(),
    );

    // 先加入用户消息并立即通知 UI，让用户输入立即显示
    _chatHistory.add(userMessage);
    notifyListeners();

    // 调用 AI 时使用不包含当前用户消息的历史，避免 _service.chat 重复追加
    final response = await _service.chat(
      config: config,
      history: List.unmodifiable(_chatHistory.sublist(0, _chatHistory.length - 1)),
      userMessage: userMessage,
      expenseCategories: expenseCategories,
      incomeCategories: incomeCategories,
    );

    // AI 响应后再追加助手消息
    _chatHistory.add(AiChatMessage(
      role: 'assistant',
      text: response.text,
      results: response.results,
      time: DateTime.now(),
    ));
    notifyListeners();
    return response;
  }

  /// 清空对话历史
  void clearChatHistory() {
    _chatHistory.clear();
    notifyListeners();
  }

  /// 对统计数据进行 AI 总结分析
  ///
  /// 使用当前激活的文本识别配置，传入统计摘要 prompt，返回分析文本。
  Future<String> analyzeStatistics(String prompt) async {
    final config = effectiveTextConfig;
    if (config == null || !config.isValid) {
      throw AiException('未选择文本识别配置');
    }
    final response = await _service.chat(
      config: config,
      history: const [],
      userMessage: AiChatMessage(
        role: 'user',
        text: prompt,
        time: DateTime.now(),
      ),
      expenseCategories: const [],
      incomeCategories: const [],
    );
    return response.text ?? '分析完成，但未返回内容';
  }

  /// 标记某条 AI 消息的识别结果已保存
  void markChatMessageSaved(int index) {
    if (index < 0 || index >= _chatHistory.length) return;
    final msg = _chatHistory[index];
    if (msg.isAssistant && msg.results.isNotEmpty && !msg.saved) {
      _chatHistory[index] = msg.copyWith(saved: true);
      notifyListeners();
    }
  }
}
