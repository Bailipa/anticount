import 'package:flutter/material.dart';

/// 标签徽章组件
///
/// 圆角容器 + 小字文本，可带前置小图标，用于"自动记账"、"AI"、"重复"等角标。
/// 颜色、字号、圆角、内边距通过参数控制，保持各使用处原有样式一致。
class TagBadge extends StatelessWidget {
  const TagBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.iconSize = 14,
    this.fontSize = 11,
  });

  /// 徽章文字
  final String label;

  /// 背景色
  final Color backgroundColor;

  /// 文字与图标颜色
  final Color textColor;

  /// 前置小图标（可选）
  final IconData? icon;

  /// 图标大小
  final double iconSize;

  /// 文字字号
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: fontSize, color: textColor)),
        ],
      ),
    );
  }
}
