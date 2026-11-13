import 'package:flutter/material.dart';

/// Figma controls keep their artwork unchanged while pressed. Selection,
/// loading and disabled states still come from the individual components.
ThemeData buildAppTheme() {
  const quietButton = ButtonStyle(
    splashFactory: NoSplash.splashFactory,
    overlayColor: WidgetStatePropertyAll(Colors.transparent),
    elevation: WidgetStatePropertyAll(0),
    shadowColor: WidgetStatePropertyAll(Colors.transparent),
  );
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3659C9)),
    useMaterial3: true,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textButtonTheme: const TextButtonThemeData(style: quietButton),
    filledButtonTheme: const FilledButtonThemeData(style: quietButton),
    elevatedButtonTheme: const ElevatedButtonThemeData(style: quietButton),
    outlinedButtonTheme: const OutlinedButtonThemeData(style: quietButton),
    iconButtonTheme: const IconButtonThemeData(style: quietButton),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      splashColor: Colors.transparent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      disabledElevation: 0,
    ),
    chipTheme: const ChipThemeData(
      elevation: 0,
      pressElevation: 0,
      shadowColor: Colors.transparent,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
