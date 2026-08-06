import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/animated_dialog.dart';
import '../../widgets/app_button.dart';
import '../settings/category_management_screen.dart';

/// 显示记账弹窗（新增 / 编辑）
Future<void> showAccountingSheet(
  BuildContext context, {
  Transaction? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AccountingSheet(editing: editing),
    ),
  );
}

/// 记账弹窗内容（新增 / 编辑）—— 以 ModalBottomSheet 形式展示
class AccountingSheet extends StatefulWidget {
  const AccountingSheet({super.key, this.editing});

  /// 传入则进入编辑模式
  final Transaction? editing;

  @override
  State<AccountingSheet> createState() => _AccountingSheetState();
}

class _AccountingSheetState extends State<AccountingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _category;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      final e = widget.editing!;
      _type = e.type;
      _category = e.category;
      _date = e.date;
      _amountCtrl.text = e.amount.toString();
      _noteCtrl.text = e.note ?? '';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  /// 添加自定义分类
  ///
  /// 使用 showTextInputDialog 让 TextEditingController 在对话框内部管理，
  /// 避免外部 dispose 控制器时对话框退出动画还在播放导致的 _dependents.isEmpty 错误。
  Future<void> _addCategory() async {
    // 在 async gap 之前预取 context 依赖
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final typeStr = _type == TransactionType.income ? 'income' : 'expense';

    // 对话框内部管理 TextEditingController 生命周期，返回输入的文本或 null
    final text = await showTextInputDialog(
      context: context,
      title: '添加分类',
      hintText: '请输入分类名称（最多 10 个字）',
      confirmText: '添加',
      cancelText: '取消',
      maxLength: 10,
    );

    // 用户取消则直接返回
    if (text == null || text.isEmpty) return;

    final added = await settings.addCategory(typeStr, text);
    if (!mounted) return;
    if (added) {
      // 自动选中新添加的分类
      setState(() => _category = text);
      messenger.showSnackBar(SnackBar(
        content: Text('已添加分类：$text'),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      await showInfoDialog(
        context: context,
        title: '添加失败',
        content: '添加失败（可能已存在或数量超限）',
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      await showInfoDialog(
        context: context,
        title: '输入有误',
        content: '金额无效，请输入大于 0 的数字',
      );
      return;
    }
    // 未选择分类时默认使用"其他"
    final settings = context.read<SettingsProvider>();
    final cats = _type == TransactionType.income
        ? settings.visibleIncomeCategories
        : settings.visibleExpenseCategories;
    if (cats.isEmpty) {
      await showInfoDialog(
        context: context,
        title: '无法记账',
        content: '没有可用分类，请先在设置中添加',
      );
      return;
    }
    _category ??= cats.contains('其他') ? '其他' : cats.first;

    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();
    bool ok;
    if (widget.editing == null) {
      ok = await provider.add(Transaction(
        userId: user.id,
        amount: amount,
        type: _type,
        category: _category!,
        date: _date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ));
    } else {
      ok = await provider.update(Transaction(
        id: widget.editing!.id,
        userId: user.id,
        amount: amount,
        type: _type,
        category: _category!,
        date: _date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ));
    }
    if (!mounted) return;
    setState(() => _saving = false);
    // 仅在失败时提示，成功时静默关闭
    if (!ok) {
      await showInfoDialog(
        context: context,
        title: '保存失败',
        content: provider.error ?? '保存失败，请重试',
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final categories = _type == TransactionType.income
        ? settings.visibleIncomeCategories
        : settings.visibleExpenseCategories;
    // 确保 _category 在当前类型可见分类列表中
    if (_category != null && !categories.contains(_category)) {
      _category = null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部拖拽指示条
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 标题 + 关闭按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.editing == null ? '记一笔' : '编辑',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('支出'),
                    icon: Icon(Icons.north_east),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('收入'),
                    icon: Icon(Icons.south_west),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _category = null;
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '金额',
                  prefixText: '${settings.currency} ',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入金额';
                  final n = double.tryParse(v.trim());
                  if (n == null || n <= 0) return '请输入有效金额';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('分类', style: Theme.of(context).textTheme.titleSmall),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CategoryManagementScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('管理'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...categories.map((c) {
                    final selected = _category == c;
                    return ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = c),
                    );
                  }),
                  // 添加自定义分类按钮
                  ActionChip(
                    label: const Text('添加'),
                    avatar: const Icon(Icons.add, size: 18),
                    onPressed: _addCategory,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('日期：'),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                onPressed: _saving ? null : _save,
                loading: _saving,
                icon: const Icon(Icons.save),
                label: widget.editing == null ? '保存' : '更新',
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
