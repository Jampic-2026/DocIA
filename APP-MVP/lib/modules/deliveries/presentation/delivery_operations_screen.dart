import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/deliveries_controller.dart';
import '../domain/delivery_summary.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';

class DeliveryOperationsScreen extends ConsumerWidget {
  const DeliveryOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(deliveriesProvider)
        .when(
          loading: () => const AppLoadingState(message: 'Cargando entregas'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(deliveriesProvider),
          ),
          data: (deliveries) {
            if (deliveries.isEmpty) {
              return const EmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'Sin entregas asignadas',
                message: 'Las entregas disponibles aparecerán en esta bandeja.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(deliveriesProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: deliveries.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) =>
                    _DeliveryCard(delivery: deliveries[index]),
              ),
            );
          },
        );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery});

  final DeliverySummary delivery;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.teal.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      delivery.scheduledAt == null
                          ? 'Sin fecha programada'
                          : DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(delivery.scheduledAt!.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: _statusLabel(delivery.status),
                color: _statusColor(delivery.status),
                dense: true,
              ),
            ],
          ),
          if (delivery.address?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.md),
            Text(delivery.address!),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            delivery.recipient?.trim().isNotEmpty ?? false
                ? 'Recibe: ${delivery.recipient}'
                : 'Sin destinatario informado',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String status) => switch (status) {
  'pending' => 'Pendiente',
  'assigned' => 'Asignada',
  'picked_up' => 'Retirada',
  'in_transit' => 'En camino',
  'delivered' => 'Entregada',
  'cancelled' => 'Cancelada',
  'failed' => 'Fallida',
  _ => status,
};

Color _statusColor(String status) => switch (status) {
  'delivered' => AppColors.success,
  'cancelled' || 'failed' => AppColors.danger,
  'in_transit' || 'picked_up' => AppColors.blue,
  _ => AppColors.warning,
};
