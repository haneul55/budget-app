import 'package:flutter/material.dart';

import '../app_theme.dart';

/// 누르고 있는 동안 살짝 음영이 생기고 안쪽으로 들어갔다가, 떼면 원래대로 돌아오는 칸.
/// (손가락이든 마우스든 같은 동작)
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.color = Colors.transparent,
    this.pressedColor = AppColors.pressed,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.pressedScale = 0.92,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color pressedColor;
  final BorderRadius borderRadius;
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 160),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _pressed ? widget.pressedColor : widget.color,
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
