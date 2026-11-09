import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../modules/auth/application/auth_controller.dart';
import '../modules/notifications/application/push_notifications_service.dart';

/// Widget raíz de la aplicación Doc IA.
///
/// Configura los temas claro/oscuro y el router (go_router) reactivo al
/// estado de sesión.
class DocIaApp extends ConsumerWidget {
  const DocIaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.isAuthenticated && previous?.user?.id != next.user?.id) {
        Future.microtask(
          () => ref
              .read(pushNotificationsServiceProvider)
              .initializeForSession(),
        );
      }
    });

    return MaterialApp.router(
      title: 'Doc IA',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'BO'),
      supportedLocales: const [
        Locale('es', 'BO'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
