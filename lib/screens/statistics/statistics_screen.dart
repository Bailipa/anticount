import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../providers/ai_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/date_helpers.dart';
import '../../utils/format.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/period_switcher.dart';
import '../ai/ai_config_screen.dart';

/// 统计总结页面
///
/// 展示收支汇总、分类饼图（按月/按年）和趋势折线图（按日/按周）。
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  /// 当前选中年月（饼图按月 / 折线图按日均以此月为基准）
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  /// 饼图聚合维度：0=按月，1=按年
  int _pieMode = 0;

  /// 柱状图聚合维度：0=按日，1=按周
  int _lineMode = 0;

  /// 柱状图显示窗口起始索引（每次展示 5 天/周）
  int _barWindowStart = 0;

  /// 月份切换动画方向（true=向右滑动，false=向左滑动）
  bool _monthSlideRight = true;

  bool _loading = true;
  List<Transaction> _transactions = [];

  /// 计算柱状图最新窗口的起始索引
  ///
  /// 默认显示最右侧（最新）的 5 个数据点。
  int _computeLatestWindowStart() {
    final data = _lineMode == 0 ? _dailyTrendData() : _weeklyTrendData();
    const windowSize = 5;
    return data.length > windowSize ? data.length - windowSize : 0;
  }

  /// AI 分析状态
  bool _analyzing = false;
  String? _analysisResult;
  String? _analysisError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  /// 当前选中年的起始
  DateTime get _yearStart => DateTime(_selectedMonth.year, 1, 1);

  /// 当前选中年的结束
  DateTime get _yearEnd =>
      DateTime(_selectedMonth.year, 12, 31, 23, 59, 59, 999);

  /// 加载范围内交易数据
  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final provider = context.read<TransactionProvider>();

    setState(() => _loading = true);

    // 按年查询，足够覆盖饼图按年、折线图按周的需求
    final items = await provider.queryByRange(
      userId: user.id,
      start: _yearStart,
      end: _yearEnd,
    );

    if (mounted) {
      setState(() {
        _transactions = items;
        _loading = false;
        // 切换月份时清空之前的分析结果
        _analysisResult = null;
        _analysisError = null;
        // 柱状图默认显示最新 5 天/周
        _barWindowStart = _computeLatestWindowStart();
      });
    }
  }

  /// 触发 AI 总结分析
  Future<void> _analyze() async {
    final ai = context.read<AiProvider>();
    setState(() {
      _analyzing = true;
      _analysisError = null;
    });

    try {
      final prompt = _buildAnalysisPrompt();
      final result = await ai.analyzeStatistics(prompt);
      if (mounted) {
        setState(() {
          _analysisResult = result;
          _analyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analysisError = e.toString();
          _analyzing = false;
        });
      }
    }
  }

  /// 构建统计分析的 prompt
  String _buildAnalysisPrompt() {
    final period = _pieMode == 0
        ? '${_selectedMonth.year}年${_selectedMonth.month}月'
        : '${_selectedMonth.year}年';
    final items = _pieTransactions;
    var income = 0.0;
    var expense = 0.0;
    final expenseByCategory = <String, double>{};
    final incomeByCategory = <String, double>{};
    for (final tx in items) {
      if (tx.isIncome) {
        income += tx.amount;
        incomeByCategory[tx.category] =
            (incomeByCategory[tx.category] ?? 0) + tx.amount;
      } else {
        expense += tx.amount;
        expenseByCategory[tx.category] =
            (expenseByCategory[tx.category] ?? 0) + tx.amount;
      }
    }

    String formatMap(Map<String, double> map) {
      final sorted = map.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.map((e) => '${e.key}: ${e.value.toStringAsFixed(2)}').join('\n');
    }

    return '''请根据以下个人记账数据给出总结分析，包括收支情况、主要支出类别、结余评价和简单理财建议。回答控制在 300 字以内。

统计周期：$period
总收入：${income.toStringAsFixed(2)}
总支出：${expense.toStringAsFixed(2)}
结余：${(income - expense).toStringAsFixed(2)}

收入分类：
${formatMap(incomeByCategory)}

支出分类：
${formatMap(expenseByCategory)}''';
  }

  /// 获取饼图使用的交易列表
  List<Transaction> get _pieTransactions {
    if (_pieMode == 0) {
      // 按月
      return _transactions.where((tx) {
        return tx.date.isAfter(
                monthStart(_selectedMonth).subtract(const Duration(seconds: 1))) &&
            tx.date.isBefore(
                monthEnd(_selectedMonth).add(const Duration(seconds: 1)));
      }).toList();
    }
    // 按年
    return _transactions;
  }

  /// 获取折线图使用的交易列表
  List<Transaction> get _lineTransactions {
    // 折线图只展示当月数据（按日/按周均在当月内）
    return _transactions.where((tx) {
      return tx.date.isAfter(
              monthStart(_selectedMonth).subtract(const Duration(seconds: 1))) &&
          tx.date.isBefore(
              monthEnd(_selectedMonth).add(const Duration(seconds: 1)));
    }).toList();
  }

  /// 按分类统计支出（饼图数据）
  Map<String, double> _categoryExpenseData() {
    final data = <String, double>{};
    for (final tx in _pieTransactions.where((t) => t.isExpense)) {
      data[tx.category] = (data[tx.category] ?? 0) + tx.amount;
    }
    return data;
  }

  /// 按分类统计收入（饼图数据）
  Map<String, double> _categoryIncomeData() {
    final data = <String, double>{};
    for (final tx in _pieTransactions.where((t) => t.isIncome)) {
      data[tx.category] = (data[tx.category] ?? 0) + tx.amount;
    }
    return data;
  }

  /// 柱状图按日聚合（包含当月所有日期，无数据为 0）
  Map<String, ({double income, double expense})> _dailyTrendData() {
    final data = <String, ({double income, double expense})>{};
    // 初始化当月每一天
    final daysInMonth = monthDays(_selectedMonth);
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      data[DateFormat('yyyy-MM-dd').format(date)] =
          (income: 0.0, expense: 0.0);
    }
    for (final tx in _lineTransactions) {
      final key = DateFormat('yyyy-MM-dd').format(tx.date);
      final current = data[key] ?? (income: 0.0, expense: 0.0);
      if (tx.isIncome) {
        data[key] = (
          income: current.income + tx.amount,
          expense: current.expense,
        );
      } else {
        data[key] = (
          income: current.income,
          expense: current.expense + tx.amount,
        );
      }
    }
    return data;
  }

  /// 柱状图按周聚合（包含当月每一周，无数据为 0）
  Map<String, ({double income, double expense})> _weeklyTrendData() {
    final data = <String, ({double income, double expense})>{};
    // 初始化当月的每一周（以周一为起点）
    var currentMonday = mondayOf(monthStart(_selectedMonth));
    while (currentMonday.isBefore(monthEnd(_selectedMonth))) {
      data[DateFormat('yyyy-MM-dd').format(currentMonday)] =
          (income: 0.0, expense: 0.0);
      currentMonday = currentMonday.add(const Duration(days: 7));
    }
    for (final tx in _lineTransactions) {
      final monday = mondayOf(tx.date);
      final key = DateFormat('yyyy-MM-dd').format(monday);
      final current = data[key] ?? (income: 0.0, expense: 0.0);
      if (tx.isIncome) {
        data[key] = (
          income: current.income + tx.amount,
          expense: current.expense,
        );
      } else {
        data[key] = (
          income: current.income,
          expense: current.expense + tx.amount,
        );
      }
    }
    return data;
  }

  /// 选择月份
  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000, 1),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: '选择月份',
    );
    if (picked != null &&
        (picked.year != _selectedMonth.year ||
            picked.month != _selectedMonth.month)) {
      setState(() {
        final next = DateTime(picked.year, picked.month);
        // 月份减小向右滑动、增大向左滑动（与账单页语义一致）
        _monthSlideRight = next.isBefore(_selectedMonth);
        _selectedMonth = next;
        // 切换月份后重置柱状图窗口
        _barWindowStart = 0;
      });
      await _loadData();
    }
  }

  void _prevMonth() {
    setState(() {
      // 月份减小：内容向右滑动
      _monthSlideRight = true;
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    setState(() {
      // 月份增大：内容向左滑动
      _monthSlideRight = false;
      _selectedMonth = next;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计总结'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: '选择月份',
            onPressed: _pickMonth,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                // 底部预留足够空位，避免被导航栏遮挡
                // AI 总结分析位于最下方，需要更多空间让其与导航栏保持距离
                padding: const EdgeInsets.only(bottom: 160),
                children: [
                  _buildMonthSwitcher(context),
                  const SizedBox(height: 8),
                  _buildSummaryCards(context, currency),
                  const SizedBox(height: 16),
                  _buildPieChartSection(context, currency),
                  const SizedBox(height: 16),
                  _buildBarChartSection(context, currency),
                  const SizedBox(height: 16),
                  _buildAiAnalysisSection(context),
                ],
              ),
            ),
    );
  }

  /// 月份切换器
  Widget _buildMonthSwitcher(BuildContext context) {
    final title = _pieMode == 0
        ? '${_selectedMonth.year}年${_selectedMonth.month}月'
        : '${_selectedMonth.year}年';
    return PeriodSwitcher(
      title: title,
      titleKey: ValueKey<String>(title),
      onPrev: _prevMonth,
      onNext: _nextMonth,
      onTitleTap: _pickMonth,
      slideRight: _monthSlideRight,
      canGoNext: true,
    );
  }

  /// 汇总卡片
  Widget _buildSummaryCards(BuildContext context, String currency) {
    final items = _pieMode == 0 ? _lineTransactions : _pieTransactions;
    var income = 0.0;
    var expense = 0.0;
    for (final tx in items) {
      if (tx.isIncome) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }
    final balance = income - expense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      label: '收入',
                      amount: income,
                      currency: currency,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryItem(
                      label: '支出',
                      amount: expense,
                      currency: currency,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _SummaryItem(
                label: '结余',
                amount: balance,
                currency: currency,
                color: balance >= 0 ? Colors.green : Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 饼图区域
  Widget _buildPieChartSection(BuildContext context, String currency) {
    final expenseData = _categoryExpenseData();
    final incomeData = _categoryIncomeData();
    final hasData = expenseData.isNotEmpty || incomeData.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '分类统计',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('按月')),
                      ButtonSegment(value: 1, label: Text('按年')),
                    ],
                    selected: {_pieMode},
                    onSelectionChanged: (value) {
                      setState(() => _pieMode = value.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!hasData)
                const SizedBox(
                  height: 200,
                  child: EmptyState(title: '暂无数据'),
                )
              else ...[
                if (expenseData.isNotEmpty)
                  _buildPieChart('支出分类', expenseData, currency, isExpense: true),
                if (expenseData.isNotEmpty && incomeData.isNotEmpty)
                  const SizedBox(height: 24),
                if (incomeData.isNotEmpty)
                  _buildPieChart('收入分类', incomeData, currency, isExpense: false),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 单个饼图
  Widget _buildPieChart(
    String title,
    Map<String, double> data,
    String currency, {
    required bool isExpense,
  }) {
    final total = data.values.fold<double>(0, (sum, v) => sum + v);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = _chartColors(sorted.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: [
                      for (var i = 0; i < sorted.length; i++)
                        PieChartSectionData(
                          color: colors[i],
                          value: sorted[i].value,
                          title:
                              '${(sorted[i].value / total * 100).toStringAsFixed(0)}%',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < sorted.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colors[i],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                sorted[i].key,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$currency${sorted[i].value.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 柱状图区域（收支统计 + 月平均线）
  ///
  /// 每次只展示 5 天/周的数据，通过在图表上左右滑动切换时间窗口。
  Widget _buildBarChartSection(BuildContext context, String currency) {
    final data = _lineMode == 0 ? _dailyTrendData() : _weeklyTrendData();
    final sortedKeys = data.keys.toList()..sort();
    final hasData = data.isNotEmpty;

    // 计算月平均线：总收入/总支出 ÷ 有效天数/周数
    final totalIncome =
        data.values.fold<double>(0, (sum, v) => sum + v.income);
    final totalExpense =
        data.values.fold<double>(0, (sum, v) => sum + v.expense);
    final avgIncome = sortedKeys.isEmpty ? 0.0 : totalIncome / sortedKeys.length;
    final avgExpense =
        sortedKeys.isEmpty ? 0.0 : totalExpense / sortedKeys.length;

    // 窗口逻辑：每次展示 5 个柱子
    const windowSize = 5;
    final maxStart = sortedKeys.length > windowSize
        ? sortedKeys.length - windowSize
        : 0;
    // 确保当前窗口起始位置在有效范围内
    final windowStart = _barWindowStart.clamp(0, maxStart);
    final windowEnd = (windowStart + windowSize).clamp(0, sortedKeys.length);
    final windowKeys = sortedKeys.sublist(windowStart, windowEnd);

    // 窗口范围文本
    String rangeText = '';
    if (windowKeys.isNotEmpty) {
      final first = DateTime.parse('${windowKeys.first} 00:00:00');
      final last = DateTime.parse('${windowKeys.last} 00:00:00');
      rangeText = _lineMode == 0
          ? '${DateFormat('M月d日').format(first)} - ${DateFormat('M月d日').format(last)}'
          : '${DateFormat('M月d日').format(first)} - ${DateFormat('M月d日').format(last.add(const Duration(days: 6)))}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '收支统计',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('按日')),
                      ButtonSegment(value: 1, label: Text('按周')),
                    ],
                    selected: {_lineMode},
                    onSelectionChanged: (value) {
                      setState(() {
                        _lineMode = value.first;
                        // 切换按日/按周后默认显示最新 5 天/周
                        _barWindowStart = _computeLatestWindowStart();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 平均线说明
              Row(
                children: [
                  _LegendItem(
                      color: Colors.green, label: '平均收入 ${avgIncome.toStringAsFixed(0)}'),
                  const SizedBox(width: 16),
                  _LegendItem(
                      color: Colors.red,
                      label: '平均支出 ${avgExpense.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 16),
              if (!hasData)
                const SizedBox(
                  height: 200,
                  child: EmptyState(title: '暂无数据'),
                )
              else ...[
                // 时间范围提示
                Center(
                  child: Text(
                    rangeText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (maxStart <= 0) return;
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity < 0 && windowStart < maxStart) {
                      // 向左滑动：显示更新的数据
                      setState(() => _barWindowStart++);
                    } else if (velocity > 0 && windowStart > 0) {
                      // 向右滑动：显示更旧的数据
                      setState(() => _barWindowStart--);
                    }
                  },
                  behavior: HitTestBehavior.translucent,
                  child: SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= windowKeys.length) {
                                  return const SizedBox.shrink();
                                }
                                final key = windowKeys[index];
                                final date = DateTime.parse('$key 00:00:00');
                                final label = _lineMode == 0
                                    ? DateFormat('d日').format(date)
                                    : DateFormat('M/d').format(date);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    label,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        barGroups: [
                          for (var i = 0; i < windowKeys.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: data[windowKeys[i]]!.income,
                                  color: Colors.green,
                                  width: 12,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                BarChartRodData(
                                  toY: data[windowKeys[i]]!.expense,
                                  color: Colors.red,
                                  width: 12,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ],
                            ),
                        ],
                        // 月平均线
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: avgIncome,
                              color: Colors.green.withAlpha(180),
                              strokeWidth: 2,
                              dashArray: [5, 5],
                            ),
                            HorizontalLine(
                              y: avgExpense,
                              color: Colors.red.withAlpha(180),
                              strokeWidth: 2,
                              dashArray: [5, 5],
                            ),
                          ],
                        ),
                        // 点击柱子查看数据（任务 46）
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final key = windowKeys[groupIndex];
                              final date = DateTime.parse('$key 00:00:00');
                              final label = _lineMode == 0
                                  ? DateFormat('M月d日').format(date)
                                  : '${DateFormat('M月d日').format(date)} - ${DateFormat('M月d日').format(date.add(const Duration(days: 6)))}';
                              final isIncome = rodIndex == 0;
                              final value = rod.toY;
                              return BarTooltipItem(
                                '$label\n',
                                const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        '${isIncome ? '收入' : '支出'}: $currency${value.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isIncome ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (maxStart > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Text(
                        '左右滑动图表切换时间窗口',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// AI 总结分析区域
  Widget _buildAiAnalysisSection(BuildContext context) {
    final ai = context.watch<AiProvider>();
    final hasTextConfig = ai.effectiveTextConfig?.isValid ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'AI 总结分析',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AiConfigScreen()),
                    ),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('切换配置'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!hasTextConfig)
                const Text(
                  '当前未配置可用的文字识别 API，点击「切换配置」进行设置。',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                )
              else if (_analysisResult == null && !_analyzing)
                Center(
                  child: FilledButton.icon(
                    onPressed: _analyze,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('生成分析'),
                  ),
                )
              else if (_analyzing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _analysisResult!,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    if (_analysisError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '错误：$_analysisError',
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _analyze,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新分析'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 生成饼图颜色
  List<Color> _chartColors(int count) {
    const palette = [
      Color(0xFF1565C0),
      Color(0xFF00ACC1),
      Color(0xFF66BB6A),
      Color(0xFFFFA726),
      Color(0xFFEF5350),
      Color(0xFFAB47BC),
      Color(0xFFEC407A),
      Color(0xFFFF7043),
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
    ];
    return List.generate(count, (i) => palette[i % palette.length]);
  }
}

/// 汇总项
class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
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
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          formatMoney(amount, currency),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// 图例项（用于柱状图平均线说明）
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
