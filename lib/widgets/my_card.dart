import 'package:flutter/material.dart';

class MyCard extends StatelessWidget {

  const MyCard({
    super.key,
    required this.child,
    this.color,
    this.shadowColor
  });
  
  final Widget child;
  final Color? color;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {

    final Color backgroundColor = color ?? ( Colors.white);
    final Color sColor = (shadowColor ?? const Color(0x80DCE7FA));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: sColor, offset: const Offset(0.0, 2.0), blurRadius: 8.0),
        ],
      ),
      child: child,
    );
  }
}
