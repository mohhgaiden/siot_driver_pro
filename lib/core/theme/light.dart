import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../router/web_page_transitions.dart';

class LightTheme {
  ThemeData light() {
    return ThemeData(
      useMaterial3: false,
      primaryColor: Colours.app_main,
      colorScheme: const ColorScheme.light(
        primary: Colours.app_main,
        secondary: Colours.app_main,
        error: Colours.red,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
      indicatorColor: Colours.app_main,
      scaffoldBackgroundColor: Colours.bg_color,
      canvasColor: Colors.white,
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: Colours.app_main.withAlpha(70),
        selectionHandleColor: Colours.app_main,
        cursorColor: Colours.app_main,
      ),
      textTheme: const TextTheme(
        titleMedium: TextStyles.text,
        bodyMedium: TextStyles.text,
        titleSmall: TextStyles.textGray12,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyles.textDarkGray14,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0.0,
        color: Colours.app_main,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      dividerTheme: const DividerThemeData(
        color: Colours.line,
        space: 0.6,
        thickness: 0.6,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colours.app_main;
          return null;
        }),
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.light,
      ),
      pageTransitionsTheme: NoTransitionsOnWeb(),
      visualDensity: VisualDensity.standard,
    );
  }
}
