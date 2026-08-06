import 'package:flutter/material.dart';

/// 通用空状态组件
///
/// 居中展示"图标 + 标题 + 可选副文案"，用于各页面的空数据占位。
/// 默认图标灰色、标题灰色、副文案灰色，可通过参数调整以保持各页面原有样式。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.icon,
    this.iconSize = 48,
    this.iconColor = Colors.grey,
    this.gap = 8,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.padding = const EdgeInsets.all(32),
  });

  /// 标题（必填）
  final String title;

  /// 图标（不传则不显示）
  final IconData? icon;

  /// 图标大小
  final double iconSize;

  /// 图标颜色
  final Color iconColor;

  /// 图标与标题间距
  final double gap;

  /// 副文案（可选）
  final String? subtitle;

  /// 标题样式（默认灰色）
  final TextStyle? titleStyle;

  /// 副文案样式（默认灰色）
  final TextStyle? subtitleStyle;

  /// 内边距
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: iconSize, color: iconColor),
              SizedBox(height: gap),
            ],
            Text(
              title,
              style: titleStyle ?? const TextStyle(color: Colors.grey),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: subtitleStyle ?? const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
