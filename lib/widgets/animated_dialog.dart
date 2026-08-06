import 'package:flutter/material.dart';

/// 带动画效果的通用对话框
///
/// 直接使用 showDialog（基于 DialogRoute）实现，不添加任何自定义包装层。
/// DialogRoute 自带淡入淡出动画，且生命周期管理最稳定。
///
/// 之前使用 showGeneralDialog + 自定义 transitionBuilder 或自定义
/// _AnimatedDialogWrapper 都可能导致关闭对话框时出现 _dependents.isEmpty
/// 断言错误，因为额外的动画 widget 层会干扰路由的依赖关系清理。
///
/// 用法（与 showDialog 一致）：
/// ```dart
/// final ok = await showAnimatedDialog<bool>(
///   context: context,
///   builder: (ctx) => AlertDialog(...),
/// );
/// ```
Future<T?> showAnimatedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Color barrierColor = Colors.black54,
  Duration transitionDuration = const Duration(milliseconds: 250),
}) {
  // 直接使用 showDialog，不包装任何自定义动画 widget。
  // DialogRoute 的默认淡入淡出动画足够，且不会产生依赖关系问题。
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useSafeArea: true,
    builder: builder,
  );
}

/// 文本输入对话框
///
/// 关键设计：TextEditingController 在对话框自己的 State 中创建和销毁，
/// 确保控制器生命周期与对话框完全一致。
///
/// 之前在外部创建 TextEditingController 并传入对话框，当对话框关闭时
/// （退出动画仍在播放），外部代码立即 dispose 控制器，导致 TextField
/// 在退出动画期间引用了已销毁的控制器，触发 _dependents.isEmpty 断言错误。
///
/// 返回用户输入的文本（trim 后），如果用户取消则返回 null。
Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  String? hintText,
  String? initialValue,
  String confirmText = '确认',
  String cancelText = '取消',
  int maxLength = 10,
}) {
  return showDialog<String?>(
    context: context,
    barrierDismissible: true,
    useSafeArea: true,
    builder: (dialogContext) => _TextInputDialog(
      title: title,
      hintText: hintText,
      initialValue: initialValue,
      confirmText: confirmText,
      cancelText: cancelText,
      maxLength: maxLength,
    ),
  );
}

/// 文本输入对话框内部实现
///
/// TextEditingController 在此 State 中管理，随对话框一起销毁。
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    this.hintText,
    this.initialValue,
    required this.confirmText,
    required this.cancelText,
    required this.maxLength,
  });

  final String title;
  final String? hintText;
  final String? initialValue;
  final String confirmText;
  final String cancelText;
  final int maxLength;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    // 使用初始值创建控制器（如有）
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    // 控制器在对话框完全销毁后才 dispose（退出动画结束后）
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
        maxLength: widget.maxLength,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(widget.cancelText),
        ),
        FilledButton(
          onPressed: () {
            final text = _ctrl.text.trim();
            Navigator.of(context).pop(text);
          },
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}

/// 通用确认对话框
///
/// 返回用户选择：true=确认，false/null=取消。
/// [danger] 为 true 时确认按钮使用红色（危险操作）；
/// [icon] 可选，在标题上方显示图标（如删除类操作）。
Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  String? content,
  String confirmText = '确认',
  String cancelText = '取消',
  bool danger = false,
  IconData? icon,
}) {
  return showDialog<bool?>(
    context: context,
    barrierDismissible: true,
    useSafeArea: true,
    builder: (dialogContext) => AlertDialog(
      title: icon == null
          ? Text(title)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 40,
                    color: Theme.of(dialogContext).colorScheme.error),
                const SizedBox(height: 12),
                Text(title),
              ],
            ),
      content: content == null ? null : Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          // 危险操作时确认按钮使用主题错误色（红色）
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

/// 信息提示弹窗（带"确认"按钮）
///
/// 用于替换重要信息/错误提示的 SnackBar，确保用户看到并确认。
///
/// [title] 标题，[content] 内容，[confirmText] 确认按钮文案（默认"确认"）。
Future<void> showInfoDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmText = '确认',
}) {
  return showAnimatedDialog<void>(
    context: context,
    barrierLabel: title,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}
