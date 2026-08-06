import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/format.dart';
import '../accounting/accounting_screen.dart';

/// 账单详情页面
///
/// 用于展示指定时间范围和类型的交易列表，
/// 例如"6月收入详情"或"6月支出详情"。
class BillsDetailScreen extends StatefulWidget {
  const BillsDetailScreen({
    super.key,
    required this.title,
    required this.start,
    required this.end,
    this.type,
  });

  /// 页面标题，如"6月收入"
  final String title;

  /// 查询起始时间
  final DateTime start;

  /// 查询结束时间
  final DateTime end;

  /// 交易类型过滤（null 表示全部）
  final TransactionType? type;

  @override
  State<BillsDetailScreen> createState() => _BillsDetailScreenState();
}

class _BillsDetailScreenState extends State<BillsDetailScreen> {
  List<Transaction> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 加载指定范围的交易数据
  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final provider = context.read<TransactionProvider>();
    final items = await provider.queryByRange(
      userId: user.id,
      start: widget.start,
      end: widget.end,
      type: widget.type,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  /// 计算列表的收支汇总
  ({double income, double expense}) get _sum {
    double income = 0, expense = 0;
    for (final tx in _items) {
      if (tx.type == TransactionType.income) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }
    return (income: income, expense: expense);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;
    final sum = _sum;
    final fmt = DateFormat('MM-dd HH:mm:ss');

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('暂无记录'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length + 1,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56, endIndent: 16),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      // 顶部汇总卡片
                      return Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: _col('收入', sum.income, currency,
                                    color: Colors.green),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: _col('支出', sum.expense, currency,
                                    color: Colors.red),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: _col(
                                    '结余',
                                    sum.income - sum.expense,
                                    currency,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final tx = _items[i - 1];
                    final isIncome = tx.type == TransactionType.income;
                    return ListTile(
                      onTap: () =>
                          showAccountingSheet(context, editing: tx),
                      leading: CircleAvatar(
                        backgroundColor:
                            (isIncome ? Colors.green : Colors.red).withAlpha(30),
                        foregroundColor: isIncome ? Colors.green : Colors.red,
                        child: Icon(
                            isIncome ? Icons.south_west : Icons.north_east),
                      ),
                      title: Text(tx.category),
                      subtitle: Text(
                        [
                          fmt.format(tx.date),
                          if (tx.note != null && tx.note!.isNotEmpty) tx.note!,
                        ].join(' · '),
                      ),
                      trailing: Text(
                        formatMoney(tx.amount, currency, sign: isIncome ? '+' : '-'),
                        style: TextStyle(
                          color: isIncome ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _col(String label, double value, String currency, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          formatMoney(value, currency),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
