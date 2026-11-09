import 'package:flutter/material.dart';

/// Paleta centralizada de la identidad Doc IA.
///
/// Los tonos base son los colores oficiales. Los tonos complementarios se
/// conservan para jerarquía, estados y accesibilidad.
abstract class AppColors {
  AppColors._();

  // --- Marca oficial ---
  static const Color brandBlue = Color(0xFF009FE3);
  static const Color brandRed = Color(0xFFE30613);

  // --- Tonos funcionales derivados de la identidad ---
  static const Color navy = Color(0xFF006B9A);
  static const Color navyDark = Color(0xFF004A6B);
  static const Color navyLight = Color(0xFF0087C1);
  static const Color blue = brandBlue;
  static const Color teal = brandBlue;
  static const Color tealDark = navyLight;
  static const Color tealLight = Color(0xFF4CC2F0);

  // --- Neutros ---
  static const Color white = Color(0xFFFFFFFF);
  /// Contraste único para texto e iconos sobre encabezados de color.
  static const Color onColoredHeader = white;
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white54 = Color(0x8AFFFFFF);
  static const Color white25 = Color(0x40FFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color white22 = Color(0x38FFFFFF);
  static const Color white20 = Color(0x33FFFFFF);
  static const Color white18 = Color(0x2EFFFFFF);
  static const Color white12 = Color(0x1FFFFFFF);
  static const Color surfaceLight = Color(0xFFF6F8FB);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color outlineLight = Color(0xFFE2E8F0);
  static const Color primaryContainerLight = Color(0xFFD9F3FD);
  static const Color secondaryContainerLight = Color(0xFFE8F7FD);
  static const Color surfaceContainerHighLight = Color(0xFFEDF1F7);
  static const Color emergencySurfaceLight = Color(0xFFE6EEF5);

  static const Color surfaceDark = Color(0xFF03283B);
  static const Color cardDark = Color(0xFF073A52);
  static const Color outlineDark = Color(0xFF145774);
  static const Color surfaceContainerHighDark = Color(0xFF0A4A68);
  static const Color emergencySurfaceDark = Color(0xFF3D111D);

  static const Color textPrimaryLight = Color(0xFF0F1B2D);
  static const Color textSecondaryLight = Color(0xFF5B6B82);
  static const Color textPrimaryDark = Color(0xFFEAF0F8);
  static const Color textSecondaryDark = Color(0xFF9DACC4);

  // --- Semánticos ---
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = brandRed;
  static const Color dangerLight = Color(0xFFFF5963);
  static const Color urgent = Color(0xFFF97316);
  static const Color info = brandBlue;
  static const Color transparent = Color(0x00000000);
  static const Color black = Color(0xFF000000);
  static const Color black35 = Color(0x59000000);
  static const Color black15 = Color(0x26000000);

  // --- Degradados de marca ---
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, blue],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, tealLight],
  );

  static const LinearGradient emergencyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [danger, dangerLight],
  );
}
