import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jampic/modules/auth/presentation/splash_screen.dart';

void main() {
  testWidgets('La splash screen muestra el eslogan de Doc IA',
      (WidgetTester tester) async {
    // Monta solo la splash screen dentro de un MaterialApp mínimo para evitar
    // dependencias del router completo.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SplashScreen()),
      ),
    );
    // Un frame inicial (la navegación ocurre tras un delay).
    await tester.pump();

    expect(find.text('Tu salud, conectada'), findsOneWidget);
  });
}
