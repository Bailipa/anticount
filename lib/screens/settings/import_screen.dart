import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../providers/ai_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/import_service.dart';
import '../../widgets/animated_dialog.dart';
import '../../widgets/app_button.dart';
import '../../widgets/tag_badge.dart';

/// 账单导入页面
///
/// 支持 CSV / Excel 文件导入。
/// - 系统格式直接解析；
/// - 非系统格式可交给 AI 解析，解析后支持手动调整；
/// - 可开启「导入后自动处理」实现 AI 解析后自动保存。
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _picking = false;
  bool _processing = false;
  String? _fileName;
  ImportResult? _result;
  List<ImportBill> _bills = const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入账单')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _buildModeSwitches(context),
          const SizedBox(height: 16),
          _buildPickButton(context),
          if (_fileName != null) ...[
            const SizedBox(height: 12),
            _buildFileInfo(context),
          ],
          if (_processing) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            const Center(child: Text('正在解析文件...')),
          ],
          if (_result?.error != null) ...[
            const SizedBox(height: 16),
            _buildErrorCard(context, _result!.error!),
          ],
          if (_bills.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildResultHeader(context),
            const SizedBox(height: 12),
            ..._bills.asMap().entries.map((e) => _buildBillCard(context, e.key, e.value)),
            const SizedBox(height: 16),
            _buildSaveButton(context),
          ],
        ],
      ),
    );
  }

  /// AI 处理模式与自动处理开关
  Widget _buildModeSwitches(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.psychology_outlined),
            title: const Text('AI 处理模式'),
            subtitle: const Text('开启后，非标准格式文件将交给 AI 解析'),
            value: settings.aiImportEnabled,
            onChanged: (v) => settings.setAiImportEnabled(v),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            secondary: const Icon(Icons.bolt_outlined),
            title: const Text('自动处理账单'),
            subtitle: const Text('AI 解析成功后自动保存，无需手动调整'),
            value: settings.autoProcessImportedBills,
            onChanged: (v) => settings.setAutoProcessImportedBills(v),
          ),
        ],
      ),
    );
  }

  /// 选择文件按钮
  Widget _buildPickButton(BuildContext context) {
    return AppButton(
      onPressed: _picking || _processing ? null : _pickAndProcess,
      loading: _picking,
      icon: const Icon(Icons.file_download_outlined),
      label: _picking ? '选择中...' : '选择文件',
      borderRadius: BorderRadius.circular(12),
    );
  }

  /// 文件名与解析信息
  Widget _buildFileInfo(BuildContext context) {
    final aiProcessed = _result?.aiProcessed ?? false;
    final parsed = _result?.parsedCount ?? 0;
    final raw = _result?.rawRowCount ?? 0;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _fileName!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              aiProcessed
                  ? 'AI 解析完成：识别到 $parsed 条账单'
                  : '系统格式解析完成：$parsed / $raw 行有效',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// 错误提示卡片
  Widget _buildErrorCard(BuildContext context, String error) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 结果列表头部（全选 / 统计）
  Widget _buildResultHeader(BuildContext context) {
    final selectedCount = _bills.where((b) => b.selected).length;
    final allSelected = selectedCount == _bills.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '共 ${_bills.length} 条，已选 $selectedCount 条',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        TextButton.icon(
          onPressed: () => _toggleSelectAll(!allSelected),
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          label: Text(allSelected ? '取消全选' : '全选'),
        ),
      ],
    );
  }

  /// 单条账单编辑卡片
  Widget _buildBillCard(BuildContext context, int index, ImportBill bill) {
    final settings = context.watch<SettingsProvider>();
    final categories = bill.type == TransactionType.income
        ? settings.incomeCategories
        : settings.expenseCategories;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：序号 + 复选框 + 删除
            Row(
              children: [
                Checkbox(
                  value: bill.selected,
                  onChanged: (v) => _updateBill(index, bill.copyWith(selected: v)),
                ),
                Expanded(
                  child: Text(
                    '账单 #${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (bill.aiSource)
                  TagBadge(
                    label: 'AI',
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    textColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                if (bill.isDuplicate) ...[
                  const SizedBox(width: 8),
                  TagBadge(
                    label: '重复',
                    backgroundColor: Colors.orange.shade100,
                    textColor: Colors.orange,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _removeBill(index),
                ),
              ],
            ),
            const Divider(height: 20),
            // 日期
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('日期'),
              trailing: Text(
                DateFormat('yyyy-MM-dd HH:mm').format(bill.date),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => _pickDateTime(index, bill),
            ),
            // 类型
            Row(
              children: [
                const Text('类型', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 16),
                Expanded(
                  child: SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('支出'),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('收入'),
                      ),
                    ],
                    selected: {bill.type},
                    onSelectionChanged: (value) {
                      final newType = value.first;
                      final newCats = newType == TransactionType.income
                          ? settings.incomeCategories
                          : settings.expenseCategories;
                      final newCategory = newCats.contains(bill.category)
                          ? bill.category
                          : (newCats.isEmpty ? '' : newCats.first);
                      _updateBill(
                        index,
                        bill.copyWith(type: newType, category: newCategory),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 分类
            Row(
              children: [
                const Text('分类', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: categories.contains(bill.category) ? bill.category : null,
                      isExpanded: true,
                      hint: const Text('选择分类'),
                      items: categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _updateBill(index, bill.copyWith(category: v));
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 金额
            TextFormField(
              initialValue: bill.amount.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              onChanged: (v) {
                final amount = double.tryParse(v) ?? bill.amount;
                if (amount > 0) {
                  _updateBill(index, bill.copyWith(amount: amount));
                }
              },
            ),
            const SizedBox(height: 12),
            // 备注
            TextFormField(
              initialValue: bill.note ?? '',
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              onChanged: (v) {
                final note = v.trim().isEmpty ? null : v.trim();
                _updateBill(index, bill.copyWith(note: note));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 保存按钮
  Widget _buildSaveButton(BuildContext context) {
    final selected = _bills.where((b) => b.selected).length;
    return AppButton(
      onPressed: selected == 0 ? null : _saveSelected,
      icon: const Icon(Icons.save),
      label: '保存选中账单（$selected 条）',
      borderRadius: BorderRadius.circular(12),
    );
  }

  /// 选择文件并处理
  Future<void> _pickAndProcess() async {
    final importService = context.read<ImportService>();
    final settings = context.read<SettingsProvider>();
    final ai = context.read<AiProvider>();
    final authProvider = context.read<AuthProvider>();
    final transactionProvider = context.read<TransactionProvider>();

    setState(() {
      _picking = true;
      _result = null;
      _bills = const [];
    });

    final picked = await importService.pickFile();
    if (picked == null) {
      setState(() => _picking = false);
      return;
    }

    setState(() {
      _picking = false;
      _processing = true;
      _fileName = picked.fileName;
    });

    try {
      ImportResult result;
      if (importService.isSystemFormat(picked.content)) {
        result = importService.parseSystemCsv(picked.content);
      } else if (settings.aiImportEnabled) {
        final config = ai.effectiveTextConfig;
        if (config == null || !config.isValid) {
          result = ImportResult(error: '当前未配置可用的文本识别模型，请先到 AI 配置页添加。');
        } else {
          result = await importService.parseWithAi(
            config: config,
            content: picked.content,
            expenseCategories: settings.expenseCategories,
            incomeCategories: settings.incomeCategories,
          );
        }
      } else {
        result = ImportResult(
          error: '文件格式与系统导出格式不符，且 AI 处理模式已关闭。'
              '请使用系统导出的 CSV 格式，或开启 AI 处理模式。',
        );
      }

      if (!mounted) return;

      if (result.error == null && result.bills.isNotEmpty) {
        final user = authProvider.user;
        if (user != null) {
          final marked = await importService.markDuplicates(
            bills: result.bills,
            userId: user.id,
          );
          result = result.copyWith(bills: marked);
        }

        if (!mounted) return;

        // 自动处理：直接保存
        if (settings.autoProcessImportedBills && result.aiProcessed) {
          await _autoSave(result.bills, authProvider, transactionProvider);
          return;
        }
      }

      setState(() {
        _processing = false;
        _result = result;
        _bills = result.bills;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _result = ImportResult(error: e.toString());
        _bills = const [];
      });
    }
  }

  /// AI 自动保存
  Future<void> _autoSave(
    List<ImportBill> bills,
    AuthProvider authProvider,
    TransactionProvider transactionProvider,
  ) async {
    final hasDuplicate = bills.any((b) => b.isDuplicate);
    if (hasDuplicate) {
      final confirmed = await showConfirmDialog(
        context: context,
        title: '发现重复账单',
        content: '检测到有 ${bills.where((b) => b.isDuplicate).length} 条账单可能与已有记录重复，是否继续保存？',
        confirmText: '继续保存',
        cancelText: '取消',
      );
      if (confirmed != true) {
        setState(() {
          _processing = false;
          _result = ImportResult(bills: bills);
          _bills = bills;
        });
        return;
      }
    }

    await _doSave(bills, authProvider, transactionProvider);
  }

  /// 保存选中的账单
  Future<void> _saveSelected() async {
    final selected = _bills.where((b) => b.selected).toList();
    if (selected.isEmpty) return;
    final authProvider = context.read<AuthProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    await _doSave(selected, authProvider, transactionProvider);
  }

  /// 执行保存
  Future<void> _doSave(
    List<ImportBill> bills,
    AuthProvider authProvider,
    TransactionProvider transactionProvider,
  ) async {
    final user = authProvider.user;
    if (user == null) return;

    setState(() => _processing = true);

    int successCount = 0;
    String? lastError;
    for (final bill in bills) {
      final ok = await transactionProvider.add(Transaction(
        userId: user.id,
        amount: bill.amount,
        type: bill.type,
        category: bill.category,
        date: bill.date,
        note: bill.note,
      ));
      if (ok) {
        successCount++;
      } else {
        lastError = transactionProvider.error;
      }
    }

    if (!mounted) return;
    setState(() => _processing = false);

    if (successCount == bills.length) {
      _showTip('成功保存 $successCount 条账单');
      setState(() {
        _bills = const [];
        _result = null;
        _fileName = null;
      });
    } else {
      if (!mounted) return;
      await showInfoDialog(
        context: context,
        title: '保存结果',
        content: '成功 $successCount / ${bills.length} 条${lastError != null ? '\n\n错误：$lastError' : ''}',
      );
    }
  }

  /// 日期时间选择
  Future<void> _pickDateTime(int index, ImportBill bill) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: bill.date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(bill.date),
    );
    if (!mounted) return;

    final newDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime?.hour ?? bill.date.hour,
      pickedTime?.minute ?? bill.date.minute,
    );
    _updateBill(index, bill.copyWith(date: newDate));
  }

  void _updateBill(int index, ImportBill bill) {
    setState(() {
      _bills = [..._bills]..[index] = bill;
    });
  }

  void _removeBill(int index) {
    setState(() {
      _bills = [..._bills]..removeAt(index);
    });
  }

  void _toggleSelectAll(bool selected) {
    setState(() {
      _bills = _bills.map((b) => b.copyWith(selected: selected)).toList();
    });
  }

  void _showTip(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}
