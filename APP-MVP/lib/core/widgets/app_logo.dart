import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

/// Logotipo oficial de Doc IA reutilizable.
///
/// Utiliza la versión positiva o blanca según el fondo, sin reconstruir,
/// recolorear ni aplicar efectos al recurso oficial.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.height = 48,
    this.width,
    this.onDark = false,
  });

  final double height;
  final double? width;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final targetHeight = (height * dpr).round().clamp(32, 1024);

    return Image.asset(
      onDark ? AppAssets.logoWhite : AppAssets.logo,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
      cacheHeight: targetHeight,
    );
  }
}
