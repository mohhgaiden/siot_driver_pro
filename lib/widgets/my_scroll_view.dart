import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:keyboard_actions/keyboard_actions.dart';

class MyScrollView extends StatelessWidget {
<<<<<<< HEAD

=======
>>>>>>> edc460f (Initial commit)
  const MyScrollView({
    super.key,
    required this.children,
    this.padding,
    this.physics = const BouncingScrollPhysics(),
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.bottomButton,
    this.keyboardConfig,
    this.tapOutsideToDismiss = false,
    this.overScroll = 16.0,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics physics;
  final CrossAxisAlignment crossAxisAlignment;
  final Widget? bottomButton;
  final KeyboardActionsConfig? keyboardConfig;
  final bool tapOutsideToDismiss;
  final double overScroll;

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD

=======
>>>>>>> edc460f (Initial commit)
    Widget contents = Column(
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );

    if (defaultTargetPlatform == TargetPlatform.iOS && keyboardConfig != null) {
<<<<<<< HEAD

      if (padding != null) {
        contents = Padding(
          padding: padding!,
          child: contents
        );
=======
      if (padding != null) {
        contents = Padding(padding: padding!, child: contents);
>>>>>>> edc460f (Initial commit)
      }

      contents = KeyboardActions(
        isDialog: bottomButton != null,
        overscroll: overScroll,
        config: keyboardConfig!,
<<<<<<< HEAD
        tapOutsideBehavior: tapOutsideToDismiss ? TapOutsideBehavior.opaqueDismiss : TapOutsideBehavior.none,
        child: contents
      );

=======
        tapOutsideBehavior:
            tapOutsideToDismiss
                ? TapOutsideBehavior.opaqueDismiss
                : TapOutsideBehavior.none,
        child: contents,
      );
>>>>>>> edc460f (Initial commit)
    } else {
      contents = SingleChildScrollView(
        padding: padding,
        physics: physics,
        child: contents,
      );
    }

    if (bottomButton != null) {
      contents = Column(
        children: <Widget>[
<<<<<<< HEAD
          Expanded(
            child: contents
          ),
          SafeArea(
            child: bottomButton!
          )
=======
          Expanded(child: contents),
          SafeArea(child: bottomButton!),
>>>>>>> edc460f (Initial commit)
        ],
      );
    }

    return contents;
  }
}
