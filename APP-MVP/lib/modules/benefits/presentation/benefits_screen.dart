import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/benefits_controller.dart';
import '../domain/benefit.dart';

class BenefitsScreen extends ConsumerWidget {
  const BenefitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Beneficios'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Disponibles'),
              Tab(text: 'Mis usos'),
            ],
          ),
        ),
        body: TabBarView(children: [_available(ref), _history(ref)]),
      ),
    );
  }

  Widget _available(WidgetRef ref) {
    return ref
        .watch(benefitsProvider)
        .when(
          loading: () => const AppLoadingState(message: 'Cargando beneficios'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(benefitsProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.redeem_outlined,
                  title: 'Sin beneficios disponibles',
                  message: 'Las promociones vigentes aparecerán aquí.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _BenefitCard(benefit: items[index]),
                  ),
                ),
        );
  }

  Widget _history(WidgetRef ref) {
    return ref
        .watch(benefitUsagesProvider)
        .when(
          loading: () =>
              const AppLoadingState(message: 'Cargando tus beneficios'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(benefitUsagesProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Sin beneficios utilizados',
                  message: 'Aquí verás los descuentos aplicados.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  itemBuilder: (_, index) =>
                      _BenefitUsageTile(usage: items[index]),
                ),
        );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.benefit});

  final Benefit benefit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.redeem_rounded, color: AppColors.teal),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  benefit.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill(
                label: benefit.available ? 'Disponible' : 'No disponible',
                color: benefit.available
                    ? AppColors.success
                    : AppColors.warning,
                dense: true,
              ),
            ],
          ),
          if (benefit.description case final description?
              when description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(description),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            _discountLabel(benefit),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.teal,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (benefit.partnerNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Válido en: ${benefit.partnerNames.join(', ')}'),
          ],
          if (benefit.validUntil case final date?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Vigente hasta ${date.day}/${date.month}/${date.year}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (benefit.maxUsesPerUser case final limit?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Usos: ${benefit.usedCount} de $limit',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  String _discountLabel(Benefit value) {
    if (value.discountPercent != null) {
      return '${value.discountPercent!.toStringAsFixed(0)}% de descuento';
    }
    if (value.discountAmount != null) {
      return 'Bs ${value.discountAmount!.toStringAsFixed(2)} de descuento';
    }
    if (value.discountCoinAmount != null) {
      return '${value.discountCoinAmount} monedas de descuento';
    }
    return 'Beneficio especial';
  }
}

class _BenefitUsageTile extends StatelessWidget {
  const _BenefitUsageTile({required this.usage});

  final BenefitUsage usage;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.check_rounded)),
      title: Text(usage.benefitName),
      subtitle: Text(
        '${usage.usedAt.day}/${usage.usedAt.month}/${usage.usedAt.year}',
      ),
      trailing: Text(
        usage.coinDiscountApplied > 0
            ? '${usage.coinDiscountApplied} monedas'
            : 'Bs ${usage.discountApplied.toStringAsFixed(2)}',
      ),
    );
  }
}
