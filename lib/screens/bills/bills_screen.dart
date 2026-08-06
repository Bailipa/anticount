import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/widget_service.dart';
import '../../utils/date_helpers.dart';
import '../../utils/format.dart';
import '../../widgets/animated_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/period_switcher.dart';
import '../../widgets/slide_transition_switcher.dart';
import '../accounting/accounting_screen.dart';
import 'bills_detail_screen.dart';

/// 账单页面（含记账入口）
///
/// 布局：
/// 1. 月份/年份切换器（左右按钮 + 点击切换，带动画）
/// 2. 月收入 / 月支出（可点击跳转到详情页）
/// 3. 周切换器
/// 4. 每日收支列表（按日期分组，可展开查看）
class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  /// 当前选中的月份（用该月第 1 天表示）
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  /// 当前选中的周（用该周周一表示）
  DateTime _selectedWeekStart = mondayOf(DateTime.now());

  /// 周切换动画方向（true=向右滑动，false=向左滑动）
  bool _weekSlideRight = true;

  /// 月份切换动画方向（true=向右滑动，false=向左滑动）
  bool _monthSlideRight = true;

  /// 月收支
  double _monthIncome = 0, _monthExpense = 0;

  /// 每日分组（key=yyyy-MM-dd，value=该日交易列表，按日期降序）
  Map<String, List<Transaction>> _dailyGroups = const {};

  bool _loading = true;

  /// 交易数据 Provider 引用（用于监听数据变更后实时刷新）
  TransactionProvider? _txProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _txProvider = context.read<TransactionProvider>();
      _txProvider?.addListener(_onDataChanged);
      _loadData();
    });
  }

  @override
  void dispose() {
    _txProvider?.removeListener(_onDataChanged);
    super.dispose();
  }

  /// 数据变更（新增/编辑/删除/导入）后实时刷新，无需手动下拉
  void _onDataChanged() {
    if (!mounted) return;
    _loadData(showLoading: false);
  }

  /// 计算时间切换时的滑动方向
  ///
  /// 按自然时间顺序：向前（更新、增长）时视觉向左滑动；向后（更旧、减小）时视觉向右滑动。
  /// 返回 [SlideTransitionSwitcher.slideRight] 所需的布尔值：
  /// - `true`：向右滑动（旧内容从左侧退出，新内容从右侧进入）
  /// - `false`：向左滑动（旧内容从右侧退出，新内容从左侧进入）
  static bool _slideRightFor(DateTime previous, DateTime current) =>
      current.isBefore(previous);

  /// 当前选中周的结束（周日 23:59:59.999）
  DateTime get _weekEnd =>
      _selectedWeekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

  /// 是否可以切换到下个月（不能超过当前月）
  bool get _canNextMonth =>
      _selectedMonth.isBefore(DateTime(DateTime.now().year, DateTime.now().month, 1));

  /// 是否可以切换到下周（不能超过当前周）
  bool get _canNextWeek => _weekEnd.isBefore(DateTime.now());

  /// 加载月/周/日数据
  ///
  /// 月收支按月范围查询；每日列表按周范围查询，这样切换周时日期列表对应更换。
  /// [targetMonth] 用于指定要加载的目标月份（月份切换时传入，不传则保持当前月份）。
  /// [targetWeekStart] 用于指定要加载的目标周（不传则使用当前 _selectedWeekStart），
  /// 切换周时先加载数据再更新状态，确保动画与数据同步。
  /// [animSlideRight] 用于指定本次周切换的视觉滑动方向（仅周切换时传入），
  /// `true` 表示向右滑动，`false` 表示向左滑动。
  /// 与数据在同一个 setState 中更新，避免快速连点时方向被覆盖。
  /// [monthAnimSlideRight] 用于指定本次月份切换的视觉滑动方向（仅月份切换时传入）。
  /// [showLoading] 是否显示全屏加载指示器（首次加载为 true，周切换为 false）。
  Future<void> _loadData({
    DateTime? targetMonth,
    DateTime? targetWeekStart,
    bool? animSlideRight,
    bool? monthAnimSlideRight,
    bool showLoading = true,
  }) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final provider = context.read<TransactionProvider>();

    final weekStart = targetWeekStart ?? _selectedWeekStart;
    final weekEnd = weekStart
        .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    // 月份切换时显式传入目标月份，避免跨月周导致标题被改回（如 2 月 1 日所在周的周一是 1 月 29 日）
    final newMonth = targetMonth ?? _selectedMonth;
    final monthStart = newMonth;
    final monthEnd = DateTime(newMonth.year, newMonth.month + 1, 0, 23, 59, 59, 999);

    // 仅首次加载显示全屏加载指示器，周切换时保持原界面，让 AnimatedSwitcher 播放动画
    if (showLoading) setState(() => _loading = true);

    // 查询本月收支（用于月收入/月支出栏），按目标周所在月份统计
    final monthSummary = await provider.summaryByRange(
      userId: user.id,
      start: monthStart,
      end: monthEnd,
    );

    // 查询本月交易笔数（用于桌面卡片）
    final monthCount = await provider.countByRange(
      userId: user.id,
      start: monthStart,
      end: monthEnd,
    );

    // 查询本周所有交易（用于每日分组）
    final weekItems = await provider.queryByRange(
      userId: user.id,
      start: weekStart,
      end: weekEnd,
    );

    // 按日分组（降序）
    final daily = <String, List<Transaction>>{};
    for (final tx in weekItems) {
      final key = DateFormat('yyyy-MM-dd').format(tx.date);
      daily.putIfAbsent(key, () => []).add(tx);
    }
    final sortedKeys = daily.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedDaily =
        Map.fromEntries(sortedKeys.map((k) => MapEntry(k, daily[k]!)));

    if (!mounted) return;
    // 同时更新 _selectedWeekStart、_selectedMonth 和数据，确保 AnimatedSwitcher 的 key
    // 变化时 child 内容已更新，动画才会正确显示新数据。
    setState(() {
      _selectedWeekStart = weekStart;
      _selectedMonth = newMonth;
      if (animSlideRight != null) _weekSlideRight = animSlideRight;
      if (monthAnimSlideRight != null) _monthSlideRight = monthAnimSlideRight;
      _monthIncome = monthSummary.income;
      _monthExpense = monthSummary.expense;
      _dailyGroups = sortedDaily;
      _loading = false;
    });

    // 同步更新桌面卡片数据
    final totalAmount = _monthIncome + _monthExpense;
    final averageAmount = monthCount > 0 ? totalAmount / monthCount : 0.0;
    unawaited(WidgetService.updateMonthlySummary(
      monthLabel: '${_selectedMonth.month}月账单',
      totalAmount: totalAmount,
      billCount: monthCount,
      averageAmount: averageAmount,
    ));
  }

  /// 根据目标月计算应显示的周
  ///
  /// 如果目标月是当前月，则显示包含今天的周；
  /// 否则显示该月第 1 天所在的周。
  DateTime _weekStartForMonth(DateTime month) {
    final now = DateTime.now();
    if (month.year == now.year && month.month == now.month) {
      return mondayOf(now);
    }
    return mondayOf(DateTime(month.year, month.month, 1));
  }

  /// 上一月
  ///
  /// 月份切换以目标月份为准，同时把周同步到该月对应的起始周。
  /// 月份减小时内容向右滑动（slideRight=true），
  /// 同步设置周列表方向，保证月份与周列表动画一致。
  void _prevMonth() {
    final newMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    final slideRight = _slideRightFor(_selectedMonth, newMonth);
    _loadData(
      targetMonth: newMonth,
      targetWeekStart: _weekStartForMonth(newMonth),
      monthAnimSlideRight: slideRight,
      animSlideRight: slideRight,
      showLoading: false,
    );
  }

  /// 下一月
  ///
  /// 月份增长时内容向左滑动（slideRight=false），
  /// 同步设置周列表方向，保证月份与周列表动画一致。
  void _nextMonth() {
    if (!_canNextMonth) return;
    final newMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    final slideRight = _slideRightFor(_selectedMonth, newMonth);
    _loadData(
      targetMonth: newMonth,
      targetWeekStart: _weekStartForMonth(newMonth),
      monthAnimSlideRight: slideRight,
      animSlideRight: slideRight,
      showLoading: false,
    );
  }

  /// 点击月份文本 → 弹出年月选择器
  Future<void> _pickMonth() async {
    final picked = await showAnimatedDialog<DateTime>(
      context: context,
      barrierLabel: '选择月份',
      builder: (_) => _MonthPickerDialog(
        initial: _selectedMonth,
        first: DateTime(2000, 1),
        last: DateTime.now(),
      ),
    );
    if (picked != null && picked != _selectedMonth) {
      final newMonth = DateTime(picked.year, picked.month, 1);
      // 月份增长时向左滑动（slideRight=false），减小时向右滑动（slideRight=true）
      final slideRight = _slideRightFor(_selectedMonth, newMonth);
      _loadData(
        targetMonth: newMonth,
        targetWeekStart: _weekStartForMonth(newMonth),
        monthAnimSlideRight: slideRight,
        animSlideRight: slideRight,
        showLoading: false,
      );
    }
  }

  /// 上一周
  ///
  /// 动画方向与数据在同一个 _loadData 调用中更新，避免快速连点时方向被覆盖。
  /// 当周跨月时，同步更新顶部月份标题。
  /// 周向前（更早）时内容向右滑动（slideRight=true），
  /// 同步设置月份标题方向，保证周列表与月份动画一致。
  void _prevWeek() {
    final newWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
    final newMonth = DateTime(newWeekStart.year, newWeekStart.month, 1);
    final weekSlideRight = _slideRightFor(_selectedWeekStart, newWeekStart);
    final monthSlideRight = _slideRightFor(_selectedMonth, newMonth);
    _loadData(
      targetMonth: newMonth,
      targetWeekStart: newWeekStart,
      animSlideRight: weekSlideRight,
      monthAnimSlideRight: monthSlideRight,
      showLoading: false,
    );
  }

  /// 下一周
  ///
  /// 周向后（更新）时内容向左滑动（slideRight=false），与月份增长方向保持一致，
  /// 同步设置月份标题方向，保证周列表与月份动画一致。
  void _nextWeek() {
    if (!_canNextWeek) return;
    final newWeekStart = _selectedWeekStart.add(const Duration(days: 7));
    final newMonth = DateTime(newWeekStart.year, newWeekStart.month, 1);
    final weekSlideRight = _slideRightFor(_selectedWeekStart, newWeekStart);
    final monthSlideRight = _slideRightFor(_selectedMonth, newMonth);
    _loadData(
      targetMonth: newMonth,
      targetWeekStart: newWeekStart,
      animSlideRight: weekSlideRight,
      monthAnimSlideRight: monthSlideRight,
      showLoading: false,
    );
  }

  /// 跳转到月收入详情
  void _gotoMonthIncome() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BillsDetailScreen(
        title: '${_selectedMonth.month}月收入',
        start: monthStart(_selectedMonth),
        end: monthEnd(_selectedMonth),
        type: TransactionType.income,
      ),
    ));
  }

  /// 跳转到月支出详情
  void _gotoMonthExpense() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BillsDetailScreen(
        title: '${_selectedMonth.month}月支出',
        start: monthStart(_selectedMonth),
        end: monthEnd(_selectedMonth),
        type: TransactionType.expense,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final user = context.watch<AuthProvider>().user;
    final currency = settings.currency;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (user != null) ...[
              CircleAvatar(
                radius: 16,
                foregroundImage:
                    user.avatar != null ? FileImage(File(user.avatar!)) : null,
                child: Text(user.initial, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(user.displayName, overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: FloatingActionButton.extended(
          onPressed: () => showAccountingSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('记账'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                // 列表底部预留足够空位，避免内容贴到记账按钮
                padding: const EdgeInsets.only(bottom: 200, top: 4),
                children: [
                  // 1. 月份/年份切换器
                  _buildMonthSwitcher(context),
                  // 2. 月收入 / 月支出
                  _buildMonthSummary(context, currency),
                  const SizedBox(height: 8),
                  // 3. 周切换器
                  _buildWeekSwitcher(context),
                  const SizedBox(height: 16),
                  // 4. 每日收支列表
                  _buildDailyList(context, currency),
                ],
              ),
            ),
    );
  }

  /// 月份/年份切换器
  ///
  /// 左右按钮 + 可点击的月份文本，标题变化时带有滑动动画，不可切换时按钮变灰。
  Widget _buildMonthSwitcher(BuildContext context) {
    final title = '${_selectedMonth.year}年${_selectedMonth.month}月';
    return PeriodSwitcher(
      title: title,
      titleKey: ValueKey<String>(title),
      onPrev: _prevMonth,
      onNext: _nextMonth,
      onTitleTap: _pickMonth,
      slideRight: _monthSlideRight,
      canGoNext: _canNextMonth,
    );
  }

  /// 月收入 / 月支出卡片（可点击跳转）
  ///
  /// 合并为一个圆角矩形，分左右两半，下方显示结余和日均。
  Widget _buildMonthSummary(BuildContext context, String currency) {
    final balance = _monthIncome - _monthExpense;
    final dayIncome = _monthIncome / monthDays(_selectedMonth);
    final dayExpense = _monthExpense / monthDays(_selectedMonth);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            // 上半部分：收入 | 支出（左右两半，可点击跳转）
            IntrinsicHeight(
              child: Row(
                children: [
                  // 月收入（点击跳转）
                  Expanded(
                    child: _SummaryHalf(
                      label: '月收入',
                      amount: _monthIncome,
                      currency: currency,
                      color: Colors.green,
                      onTap: _gotoMonthIncome,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  // 月支出（点击跳转）
                  Expanded(
                    child: _SummaryHalf(
                      label: '月支出',
                      amount: _monthExpense,
                      currency: currency,
                      color: Colors.red,
                      onTap: _gotoMonthExpense,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            // 下半部分：结余 + 日均
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoItem(
                    label: '结余',
                    amount: balance,
                    currency: currency,
                    color: balance >= 0 ? Colors.green : Colors.red,
                  ),
                  _InfoItem(
                    label: '日均收入',
                    amount: dayIncome,
                    currency: currency,
                    color: Colors.green,
                  ),
                  _InfoItem(
                    label: '日均支出',
                    amount: dayExpense,
                    currency: currency,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 周切换器
  ///
  /// 左右按钮 + 周日期文本，标题变化时带有与月份切换一致的滑动动画。
  Widget _buildWeekSwitcher(BuildContext context) {
    final weekEnd = _selectedWeekStart.add(const Duration(days: 6));
    final title =
        '${DateFormat('MM-dd').format(_selectedWeekStart)} ~ ${DateFormat('MM-dd').format(weekEnd)}';
    return PeriodSwitcher(
      title: title,
      titleKey: ValueKey<String>(title),
      onPrev: _prevWeek,
      onNext: _nextWeek,
      slideRight: _weekSlideRight,
      canGoNext: _canNextWeek,
      outerPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      containerPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      borderRadius: 16,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    );
  }

  /// 每日收支列表（按日期分组，可展开查看）
  ///
  /// 切换周时列表整体有滑动 + 淡入淡出的切换动画，
  /// 周切换器标题也使用同样的滑动动画。
  Widget _buildDailyList(BuildContext context, String currency) {
    if (_dailyGroups.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy,
        title: '本周暂无账单记录',
      );
    }
    // SlideTransitionSwitcher：切换周时列表整体滑动 + 淡入淡出
    return SlideTransitionSwitcher(
      slideRight: _weekSlideRight,
      duration: const Duration(milliseconds: 300),
      // key 随选中周变化，触发动画
      child: Column(
        key: ValueKey(_selectedWeekStart.toIso8601String()),
        children: _dailyGroups.entries.map((entry) {
          return _DailyCard(
            dateKey: entry.key,
            transactions: entry.value,
            currency: currency,
            onEdit: (tx) => showAccountingSheet(context, editing: tx),
            onDelete: (tx) => _confirmDelete(context, tx),
          );
        }).toList(),
      ),
    );
  }

  /// 确认删除
  Future<void> _confirmDelete(BuildContext context, Transaction tx) async {
    final ok = await showConfirmDialog(
      context: context,
      title: '删除记账',
      content: '确认删除该条记录？此操作不可恢复。',
      confirmText: '删除',
      danger: true,
      icon: Icons.delete_outline,
    );
    if (ok == true && context.mounted) {
      final user = context.read<AuthProvider>().user;
      final provider = context.read<TransactionProvider>();
      if (user != null) {
        await provider.delete(tx.id!, user.id);
        await _loadData();
      }
    }
  }
}

/// 收支汇总半块（用于圆角矩形内左右两半）
///
/// 显示标签 + 金额，可选支持点击跳转。
class _SummaryHalf extends StatelessWidget {
  const _SummaryHalf({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    this.onTap,
  });

  final String label;
  final double amount;
  final String currency;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            formatMoney(amount, currency),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          // 可点击时显示跳转提示
          if (onTap != null) ...[
            const SizedBox(height: 2),
            Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
          ],
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }
    return content;
  }
}

/// 信息小项（结余、日均等）
class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  final String label;
  final double amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          formatMoney(amount, currency),
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 每日账单卡片
///
/// 显示某日期的收支汇总，点击展开/折叠查看该日详细交易。
class _DailyCard extends StatefulWidget {
  const _DailyCard({
    required this.dateKey,
    required this.transactions,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final String dateKey; // yyyy-MM-dd
  final List<Transaction> transactions;
  final String currency;
  final void Function(Transaction) onEdit;
  final void Function(Transaction) onDelete;

  @override
  State<_DailyCard> createState() => _DailyCardState();
}

class _DailyCardState extends State<_DailyCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(widget.dateKey);
    final weekday = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][date.weekday - 1];
    double income = 0, expense = 0;
    for (final tx in widget.transactions) {
      if (tx.type == TransactionType.income) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            // 日期标题行（点击展开/折叠）
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // 日期 + 星期
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MM-dd').format(date),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        Text(weekday,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // 收支汇总
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (income > 0)
                            Text(formatMoney(income, widget.currency, prefix: '收入 '),
                                style: const TextStyle(
                                    color: Colors.green, fontSize: 12)),
                          if (income > 0 && expense > 0)
                            const SizedBox(width: 8),
                          if (expense > 0)
                            Text(formatMoney(expense, widget.currency, prefix: '支出 '),
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 展开/折叠箭头
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.chevron_right, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            // 展开后显示该日详细交易
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  for (final tx in widget.transactions) ...[
                    _TransactionTile(
                      tx: tx,
                      currency: widget.currency,
                      onEdit: () => widget.onEdit(tx),
                      onDelete: () => widget.onDelete(tx),
                    ),
                    if (tx != widget.transactions.last)
                      const Divider(height: 1, indent: 56, endIndent: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.tx,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final Transaction tx;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == TransactionType.income;
    final fmt = DateFormat('HH:mm:ss');
    return ListTile(
      onTap: onEdit,
      leading: CircleAvatar(
        backgroundColor: (isIncome ? Colors.green : Colors.red).withAlpha(30),
        foregroundColor: isIncome ? Colors.green : Colors.red,
        child: Icon(isIncome ? Icons.south_west : Icons.north_east),
      ),
      title: Text(tx.category),
      subtitle: Text(
        [
          fmt.format(tx.date),
          if (tx.note != null && tx.note!.isNotEmpty) tx.note!,
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(tx.amount, currency, sign: isIncome ? '+' : '-'),
            style: TextStyle(
              color: isIncome ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: '编辑',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '删除',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// 月份选择对话框
///
/// 通过 Cupertino 风格的滚轮选择年月。
class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({
    required this.initial,
    required this.first,
    required this.last,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择月份'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 年份选择
              DropdownButton<int>(
                value: _year,
                items: [
                  for (var y = widget.first.year; y <= widget.last.year; y++)
                    DropdownMenuItem(value: y, child: Text('$y年')),
                ],
                onChanged: (v) => setState(() => _year = v!),
              ),
              const SizedBox(width: 16),
              // 月份选择
              DropdownButton<int>(
                value: _month,
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(value: m, child: Text('$m月')),
                ],
                onChanged: (v) => setState(() => _month = v!),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, DateTime(_year, _month, 1)),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
