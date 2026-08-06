import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/ai_service.dart';

/// 判断两个日期是否为同一天
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 检测识别结果中是否有与已有账单重复的
///
/// 判断条件：同一用户、同一天、相同金额、相同类型、相同分类。
/// 返回每个识别结果对应的重复交易列表（索引与 results 对应）。
/// [userId] 为 null（未登录）时直接返回空列表。
Future<List<List<Transaction>>> findDuplicateTransactions({
  required int? userId,
  required TransactionProvider provider,
  required List<AiRecognitionResult> results,
}) async {
  if (userId == null) return List.generate(results.length, (_) => []);

  final now = DateTime.now();
  // 查询最近 7 天的交易用于比对
  final recent = await provider.queryByRange(
    userId: userId,
    start: now.subtract(const Duration(days: 7)),
    end: now,
  );

  // 为每个识别结果查找重复
  final duplicates = <List<Transaction>>[];
  for (final result in results) {
    final type = result.type == 'income'
        ? TransactionType.income
        : TransactionType.expense;
    // 重复判断：同一天、相同金额、相同类型、相同分类
    final matches = recent.where((tx) {
      return tx.amount == result.amount &&
          tx.type == type &&
          tx.category == result.category &&
          isSameDay(tx.date, now);
    }).toList();
    duplicates.add(matches);
  }
  return duplicates;
}
