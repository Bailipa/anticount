import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/ai_service.dart';

/// AI 识别结果批量保存的结果
class AiSaveResult {
  const AiSaveResult({required this.successCount, required this.lastError});

  /// 成功保存的条数
  final int successCount;

  /// 最后一条失败的错误信息（全部成功时为 null）
  final String? lastError;
}

/// 批量保存 AI 识别结果
///
/// 遍历识别结果逐条构造 [Transaction] 并写入数据库，
/// 返回成功条数与最后一次错误。
/// 各界面保存成功/失败后的 UI 反馈（弹窗、清空列表、标记消息等）由调用方处理。
Future<AiSaveResult> saveAiResults({
  required TransactionProvider provider,
  required int userId,
  required List<AiRecognitionResult> results,
}) async {
  int successCount = 0;
  String? lastError;
  final now = DateTime.now();
  for (final result in results) {
    final ok = await provider.add(Transaction(
      userId: userId,
      amount: result.amount,
      type: result.type == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      category: result.category,
      date: now,
      note: result.note,
    ));
    if (ok) {
      successCount++;
    } else {
      lastError = provider.error;
    }
  }
  return AiSaveResult(successCount: successCount, lastError: lastError);
}
