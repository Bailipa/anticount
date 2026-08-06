import 'package:flutter/material.dart';

/// 通用 Overlay 下拉组件
///
/// 通过 GlobalKey 获取锚点组件的位置与大小，将选项列表弹出到锚点正下方。
/// 支持：
/// - 点击锚点展开/收起，点击遮罩或选项关闭；
/// - 右对齐锚点（弹层按内容自适应宽度）或左对齐且与锚点等宽；
/// - 当前项选中高亮（主色图标/文字 + 勾选）；
/// - 卷帘门（从顶部向下展开）动画。
class OverlayDropdown<T> extends StatefulWidget {
  const OverlayDropdown({
    super.key,
    required this.anchor,
    required this.items,
    required this.onSelected,
    this.itemLabelOf,
    this.itemIconOf,
    this.isSelected,
    this.itemBuilder,
    this.onDismiss,
    this.rightAligned = false,
    this.animate = false,
  });

  /// 触发锚点组件构建器
  ///
  /// [onTap] 用于切换下拉展开/收起，由调用方绑定到触发组件上。
  final Widget Function(BuildContext context, VoidCallback onTap) anchor;

  /// 下拉选项列表
  final List<T> items;

  /// 选中某个选项时的回调
  final ValueChanged<T> onSelected;

  /// 获取选项显示文本（默认项渲染使用）
  final String Function(T item)? itemLabelOf;

  /// 获取选项图标（默认项渲染使用，返回 null 时不显示图标）
  final IconData Function(T item)? itemIconOf;

  /// 判断选项是否为当前选中项（用于高亮）
  final bool Function(T item)? isSelected;

  /// 完全自定义选项内容渲染（传入后忽略默认项渲染）
  final Widget Function(BuildContext context, T item, bool selected)?
      itemBuilder;

  /// 下拉关闭回调（点击遮罩关闭时触发）
  final VoidCallback? onDismiss;

  /// 是否右对齐锚点（默认左对齐且宽度与锚点一致）
  final bool rightAligned;

  /// 是否启用卷帘门展开动画
  final bool animate;

  @override
  State<OverlayDropdown<T>> createState() => _OverlayDropdownState<T>();
}

class _OverlayDropdownState<T> extends State<OverlayDropdown<T>>
    with SingleTickerProviderStateMixin {
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _animCtrl.dispose();
    super.dispose();
  }

  /// 移除弹出层
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// 切换展开/收起（再次点击锚点收起）
  void _toggle() {
    if (_overlayEntry != null) {
      _close();
    } else {
      _open();
    }
  }

  /// 打开下拉
  ///
  /// 通过锚点的 GlobalKey 获取其位置与大小，将选项列表定位在锚点正下方。
  void _open() {
    final renderBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final rect = position & size;

    _overlayEntry = OverlayEntry(
      builder: (context) => _OverlayDropdownPanel<T>(
        rect: rect,
        widget: widget,
        animation: _animCtrl,
        onSelect: (item) {
          _close();
          widget.onSelected(item);
        },
        onDismiss: () {
          _close();
          widget.onDismiss?.call();
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    if (widget.animate) _animCtrl.forward(from: 0);
  }

  /// 关闭下拉（启用动画时先播放收起动画再移除）
  void _close() {
    if (!widget.animate) {
      _removeOverlay();
      return;
    }
    _animCtrl.reverse().then((_) {
      _removeOverlay();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // 用 KeyedSubtree 持有 GlobalKey，以便获取锚点渲染位置
    return KeyedSubtree(
      key: _anchorKey,
      child: widget.anchor(context, _toggle),
    );
  }
}

/// 下拉面板（Overlay 内容）
class _OverlayDropdownPanel<T> extends StatelessWidget {
  const _OverlayDropdownPanel({
    required this.rect,
    required this.widget,
    required this.animation,
    required this.onSelect,
    required this.onDismiss,
  });

  /// 锚点的位置和大小
  final Rect rect;

  /// 父级通用组件（读取各项配置）
  final OverlayDropdown<T> widget;

  /// 卷帘门动画控制器
  final AnimationController animation;

  /// 选中选项回调
  final ValueChanged<T> onSelect;

  /// 点击遮罩关闭回调
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final body = _buildPanelBody(context);
    return Stack(
      children: [
        // 全屏透明遮罩，点击关闭
        GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
        // 弹出列表：右对齐时按内容自适应宽度，否则与锚点等宽并左对齐
        if (widget.rightAligned)
          Positioned(
            right: MediaQuery.of(context).size.width - rect.right,
            top: rect.bottom + 4,
            child: body,
          )
        else
          Positioned(
            left: rect.left,
            top: rect.bottom + 4,
            width: rect.width,
            child: body,
          ),
      ],
    );
  }

  /// 面板主体（含卷帘门动画）
  Widget _buildPanelBody(BuildContext context) {
    final body = Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in widget.items) _buildItem(context, item),
          ],
        ),
      ),
    );

    if (!widget.animate) return body;
    // 卷帘门效果：用 ClipRect + Align(heightFactor) 从顶部向下展开
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: animation.value,
            child: child,
          ),
        );
      },
      child: body,
    );
  }

  /// 渲染单个选项
  Widget _buildItem(BuildContext context, T item) {
    final selected = widget.isSelected?.call(item) ?? false;
    return InkWell(
      onTap: () => onSelect(item),
      child: widget.itemBuilder != null
          ? widget.itemBuilder!(context, item, selected)
          : _buildDefaultItem(context, item, selected),
    );
  }

  /// 默认选项内容：图标 + 文本 + 选中勾选
  Widget _buildDefaultItem(BuildContext context, T item, bool selected) {
    final label = widget.itemLabelOf?.call(item) ?? item.toString();
    final icon = widget.itemIconOf?.call(item);
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontSize: 14,
      color: selected ? colorScheme.primary : null,
      fontWeight: selected ? FontWeight.w600 : null,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        // 右对齐时按内容宽度；等宽时撑满整行（文字用 Expanded）
        mainAxisSize:
            widget.rightAligned ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: selected ? colorScheme.primary : Colors.grey[600],
            ),
            const SizedBox(width: 8),
          ],
          if (widget.rightAligned)
            Text(label, style: labelStyle)
          else
            Expanded(child: Text(label, style: labelStyle)),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check, size: 16, color: colorScheme.primary),
          ],
        ],
      ),
    );
  }
}
