import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_provider.dart';
import '../../services/export_service.dart';
import '../../widgets/animated_dialog.dart';
import '../../widgets/app_button.dart';

/// 账单导出页面
///
/// 用户可选择导出的日期范围，默认导出当前月的账单。
/// 导出完成后通过系统分享面板分享 CSV 文件。
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late DateTime _start;
  late DateTime _end;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // 默认导出当前月
    _start = DateTime(now.year, now.month, 1);
    _end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  }

  /// 选择开始日期
  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: _end,
    );
    if (picked != null) {
      setState(() => _start = picked);
    }
  }

  /// 选择结束日期
  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      // 结束日期默认到当天最后一刻
      setState(() => _end = DateTime(picked.year, picked.month, picked.day,
          23, 59, 59, 999));
    }
  }

  /// 快捷选择：本月、上月、近 30 天
  void _applyShortcut(String type) {
    final now = DateTime.now();
    switch (type) {
      case '本月':
        _start = DateTime(now.year, now.month, 1);
        _end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
      case '上月':
        _start = DateTime(now.year, now.month - 1, 1);
        _end = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
      case '近30天':
        _end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        _start = _end.subtract(const Duration(days: 29));
        _start = DateTime(_start.year, _start.month, _start.day);
    }
    setState(() {});
  }

  /// 执行导出并通过系统分享面板分享
  Future<void> _export() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      await showInfoDialog(
        context: context,
        title: '导出失败',
        content: '请先登录',
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final path = await context.read<ExportService>().exportToCsv(
            userId: user.id,
            start: _start,
            end: _end,
          );
      if (!mounted) return;
      // 分享导出的 CSV 文件
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Anticount 账单导出',
      );
    } catch (e) {
      if (!mounted) return;
      await showInfoDialog(
        context: context,
        title: '导出失败',
        content: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导出账单')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 快捷选项
          Wrap(
            spacing: 8,
            children: ['本月', '上月', '近30天']
                .map((label) => ActionChip(
                      label: Text(label),
                      onPressed: () => _applyShortcut(label),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          // 开始日期
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('开始日期'),
              trailing: Text(_fmt(_start),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: _pickStart,
            ),
          ),
          const SizedBox(height: 12),
          // 结束日期
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('结束日期'),
              trailing: Text(_fmt(_end),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: _pickEnd,
            ),
          ),
          const SizedBox(height: 24),
          // 导出按钮
          AppButton(
            onPressed: _exporting ? null : _export,
            loading: _exporting,
            icon: const Icon(Icons.file_upload_outlined),
            label: _exporting ? '导出中...' : '导出 CSV',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }
}
