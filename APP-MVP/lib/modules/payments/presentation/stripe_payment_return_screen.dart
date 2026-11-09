import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../coins/application/coins_controller.dart';
import '../application/payments_controller.dart';

class StripePaymentReturnScreen extends ConsumerStatefulWidget {
  const StripePaymentReturnScreen({
    super.key,
    required this.status,
    required this.sessionId,
  });

  final String? status;
  final String? sessionId;

  @override
  ConsumerState<StripePaymentReturnScreen> createState() =>
      _StripePaymentReturnScreenState();
}

class _StripePaymentReturnScreenState
    extends ConsumerState<StripePaymentReturnScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finishReturn());
  }

  Future<void> _finishReturn() async {
    final success = widget.status == 'success';
    final sessionId = widget.sessionId;
    var synced = false;
    try {
      if (success && sessionId != null && sessionId.isNotEmpty) {
        await ref
            .read(paymentsRepositoryProvider)
            .syncStripeCheckoutSession(sessionId);
        synced = true;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pago recibido, pero no pudimos actualizar el saldo: $error',
          ),
        ),
      );
    }

    ref.invalidate(paymentOrdersProvider);
    ref.invalidate(paymentHistoryProvider);
    ref.invalidate(coinOverviewProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success && synced
              ? 'Pago exitoso. Tus monedas fueron actualizadas.'
              : success
              ? 'Pago recibido. Revisa tu saldo en unos segundos.'
              : 'Pago cancelado o no completado.',
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    context.go(success ? AppRoutes.patientCoins : AppRoutes.payments);
  }

  @override
  Widget build(BuildContext context) {
    final success = widget.status == 'success';
    return Scaffold(
      appBar: AppBar(title: const Text('Pago con tarjeta')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  success
                      ? Icons.check_circle_outline
                      : Icons.info_outline_rounded,
                  size: 44,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  success ? 'Pago recibido' : 'Pago no completado',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  success
                      ? 'Te llevaremos a Monedas Doc IA para ver tu saldo.'
                      : 'Te llevaremos nuevamente a Pagos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
