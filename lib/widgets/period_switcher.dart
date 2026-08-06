import 'package:flutter/material.dart';

import 'slide_transition_switcher.dart';

/// 可复用的周期切换器（月份/周等）
///
/// 左右导航按钮 + 可点击标题，标题变化时通过 [SlideTransitionSwitcher] 播放滑动动画。
/// [slideRight] 控制标题切换的视觉方向，语义与 [SlideTransitionSwitcher.slideRight] 一致。
class PeriodSwitcher extends StatelessWidget {
  const PeriodSwitcher({
    super.key,
    required this.title,
    required this.titleKey,
    required this.onPrev,
    required this.onNext,
    this.onTitleTap,
    required this.slideRight,
    this.canGoNext = true,
    this.backgroundColor,
    this.titleStyle,
    this.containerPadding,
    this.outerPadding,
    this.borderRadius,
  });

  /// 当前标题文本
  final String title;

  /// 用于触发动画的 key，通常基于时间生成
  final Key titleKey;

  /// 点击左按钮
  final VoidCallback onPrev;

  /// 点击右按钮
  final VoidCallback onNext;

  /// 点击标题（可选）
  final VoidCallback? onTitleTap;

  /// 标题切换方向：true=向右滑动，false=向左滑动
  final bool slideRight;

  /// 右按钮是否可用
  final bool canGoNext;

  /// 标题容器背景色
  final Color? backgroundColor;

  /// 标题文本样式
  final TextStyle? titleStyle;

  /// 标题容器内边距
  final EdgeInsetsGeometry? containerPadding;

  /// 组件整体外边距
  final EdgeInsetsGeometry? outerPadding;

  /// 标题容器圆角
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: outerPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: Icons.chevron_left,
            onPressed: onPrev,
            enabled: true,
          ),
          GestureDetector(
            onTap: onTitleTap,
            child: Container(
              padding: containerPadding ??
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius ?? 20),
                color: backgroundColor ?? colorScheme.primaryContainer,
              ),
              child: SlideTransitionSwitcher(
                slideRight: slideRight,
                child: Text(
                  key: titleKey,
                  title,
                  style: titleStyle ??
                      TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
              ),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right,
            onPressed: onNext,
            enabled: canGoNext,
          ),
        ],
      ),
    );
  }
}

/// 导航按钮（左右切换）
///
/// 不可切换时 [enabled] 为 false，按钮变灰且不响应点击。
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onPressed,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: enabled ? onPressed : null,
      color: Theme.of(context).colorScheme.primary,
      disabledColor: Colors.grey.shade400,
    );
  }
}
