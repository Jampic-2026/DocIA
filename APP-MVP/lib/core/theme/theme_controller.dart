import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controla el [ThemeMode] de la aplicación (claro / oscuro / sistema).
///
/// En una versión con backend, la preferencia podría persistirse (p. ej. en
/// SharedPreferences); aquí se mantiene en memoria para el MVP de UI.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void toggleFromBrightness(Brightness brightness) {
    state = brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void set(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
