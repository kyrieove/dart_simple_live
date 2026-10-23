import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_theme.dart';

typedef FocusOnKeyDownCallback = KeyEventResult Function();

/// 高亮组件
class HighlightWidget extends StatelessWidget {
  final AppFocusNode focusNode;
  final Widget child;
  final FocusOnKeyDownCallback? onUpKey;
  final FocusOnKeyDownCallback? onDownKey;
  final FocusOnKeyDownCallback? onLeftKey;
  final FocusOnKeyDownCallback? onRightKey;
  final Function(bool)? onFocusChange;
  final Function()? onTap;
  final Color foucsedColor;
  final Color color;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final double order;
  final bool selected;
  const HighlightWidget({
    required this.focusNode,
    required this.child,
    this.onUpKey,
    this.onDownKey,
    this.onLeftKey,
    this.onRightKey,
    this.onFocusChange,
    this.onTap,
    this.autofocus = false,
    this.selected = false,
    this.borderRadius,
    this.order = 0.0,
    this.color = Colors.transparent,
    this.foucsedColor = Colors.white,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final focusColor = AppTheme.focusColor(accent);
    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: Focus(
        focusNode: focusNode,
        autofocus: autofocus,
        onFocusChange: onFocusChange,
        onKeyEvent: (node, e) {
          if (e is KeyDownEvent) {
            if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
              return onRightKey?.call() ?? KeyEventResult.ignored;
            }
            if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
              return onLeftKey?.call() ?? KeyEventResult.ignored;
            }
            if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
              return onUpKey?.call() ?? KeyEventResult.ignored;
            }
            if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
              return onDownKey?.call() ?? KeyEventResult.ignored;
            }
            if (e.logicalKey == LogicalKeyboardKey.enter ||
                e.logicalKey == LogicalKeyboardKey.select ||
                e.logicalKey == LogicalKeyboardKey.space) {
              // 这里必须自己调用再返回结果, 不能写 onTap?.call() ?? ...
              // onTap 声明成 Function(), 返回值是 dynamic, 而 onTap 是
              // async void 时拿到的是 Future, 隐式转成 KeyEventResult 会直接抛类型错误,
              // 按 OK 键的这次操作就废了。
              onTap?.call();
              return KeyEventResult.handled;
            }
          }

          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: onTap,
          child: Obx(
            () => AnimatedScale(
              scale: focusNode.isFoucsed.value ? 1.06 : 1,
              duration: const Duration(milliseconds: 180),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: focusNode.isFoucsed.value
                          ? focusColor
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: focusNode.isFoucsed.value
                        ? [
                            BoxShadow(
                              color: accent.withAlpha(70),
                              blurRadius: 26.w,
                              spreadRadius: 1.w,
                            ),
                          ]
                        : null,
                    color: (focusNode.isFoucsed.value || selected)
                        ? foucsedColor
                        : color,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
