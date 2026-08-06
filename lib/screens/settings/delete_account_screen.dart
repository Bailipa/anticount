import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/animated_dialog.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _agreed = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      await showInfoDialog(
        context: context,
        title: '需要确认',
        content: '请先勾选"我确认删除账号"复选框',
      );
      return;
    }
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().deleteAccount(_passwordCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('账号已删除'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // 删除成功后弹回根路由，避免 push 出的页面盖住登录页
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      await showInfoDialog(
        context: context,
        title: '删除失败',
        content: context.read<AuthProvider>().error ?? '删除失败，请重试',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('删除账号')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Theme.of(context).colorScheme.error),
                            const SizedBox(width: 8),
                            Text('危险操作',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '删除账号将永久清除你的全部信息，包括所有记账和账单数据，且无法恢复。',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _passwordCtrl,
                  label: '输入当前账号密码以确认',
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline),
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '请输入密码' : null,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                  title: const Text('我已知晓删除后果，确认删除账号'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: '永久删除账号',
                  loading: _loading,
                  danger: true,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
