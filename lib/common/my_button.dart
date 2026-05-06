import 'package:flutter/material.dart';
import '../core/constants/colors.dart';
import '../core/constants/dimens.dart';

class MyButton extends StatelessWidget {
  const MyButton({
    super.key,
    this.text = '',
    this.fontSize = Dimens.font_sp18,
    this.textColor,
    this.disabledTextColor,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.minHeight = 48.0,
    this.minWidth = double.infinity,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.radius = 8.0,
    this.side = BorderSide.none,
    required this.onPressed,
  });

  final String text;
  final double fontSize;
  final Color? textColor;
  final Color? disabledTextColor;
  final Color? backgroundColor;
  final Color? disabledBackgroundColor;
  final double? minHeight;
  final double? minWidth;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final double radius;
  final BorderSide side;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return disabledTextColor ?? Colours.text_disabled;
          }
          return textColor ?? Colors.white;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return disabledBackgroundColor ?? Colours.button_disabled;
          }
          return backgroundColor ?? Colours.app_main;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          return (textColor ?? Colors.white).withValues(alpha: 0.12);
        }),
        minimumSize:
            (minWidth == null || minHeight == null)
                ? null
                : WidgetStateProperty.all<Size>(Size(minWidth!, minHeight!)),
        padding: WidgetStateProperty.all<EdgeInsetsGeometry>(padding),
        shape: WidgetStateProperty.all<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
        side: WidgetStateProperty.all<BorderSide>(side),
      ),
      child: Text(text, style: TextStyle(fontSize: fontSize)),
    );
  }
}
