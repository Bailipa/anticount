// 历史账单上下文构建辅助
//
// 让 AI 记账/对话识别时能参考用户已记录的历史账单，
// 而不是只依赖当前对话上下文（保持分类一致、辅助判断重复）。
// 无历史记录时返回 null，调用方跳过注入，不影响首次识别。

import '../models/transaction.dart';
import '../providers/transaction_provider.dart';

/// 查询用户最近 [days] 天内的账单并格式化为 AI 参考上下文
///
/// 最多取 [limit] 条（按日期倒序，最新的在前），无记录时返回 null。
Future<String?> buildRecentTransactionsContext({
  required int userId,
  required TransactionProvider provider,
  String currency = '¥',
  int days = 90,
  int limit = 30,
}) async {
  final txs = await provider.queryByRange(
    userId: userId,
    start: DateTime.now().subtract(Duration(days: days)),
  );
  if (txs.isEmpty) return null;
  return formatRecentTransactionsContext(txs.take(limit).toList(), currency);
}

/// 把交易列表格式化为提示词中的"历史账单参考"段落
///
/// 公开以便单测校验输出格式（不出现 null 等字面量）。
String formatRecentTransactionsContext(List<Transaction> txs, String currency) {
  if (txs.isEmpty) return '';
  final buffer = StringBuffer();
  buffer.write('历史账单参考（以下是用户最近记录的账单，供你保持分类习惯、判断是否重复，不必严格照搬）：\n');
  buffer.write('最近记录：\n');
  for (final tx in txs) {
    final d = tx.date;
    buffer.write('- ${d.month}月${d.day}日 ${tx.type.label} ${tx.category} '
        '$currency${tx.amount.toStringAsFixed(2)}');
    final note = tx.note?.trim();
    if (note != null && note.isNotEmpty) {
      buffer.write('（备注：$note）');
    }
    buffer.write('\n');
  }

  // 支出分类统计：帮助 AI 选择与历史一致的分类
  final expenseByCat = <String, ({int count, double sum})>{};
  for (final tx in txs.where((t) => t.isExpense)) {
    final cur = expenseByCat.putIfAbsent(tx.category, () => (count: 0, sum: 0));
    expenseByCat[tx.category] = (count: cur.count + 1, sum: cur.sum + tx.amount);
  }
  if (expenseByCat.isNotEmpty) {
    final stats = expenseByCat.entries
        .map((e) =>
            '${e.key} ${e.value.count}笔 $currency${e.value.sum.toStringAsFixed(2)}')
        .join('；');
    buffer.write('支出分类统计：$stats\n');
  }

  return buffer.toString();
}
