import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/authorization/permission_codes.dart';
import '../../../core/responsive/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../application/catalog_controller.dart';
import '../domain/catalog_item.dart';
import '../domain/catalog_repository.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage =
        ref.watch(authControllerProvider).user?.can(PermissionCodes.catalogManage) ??
            false;
    if (canManage) return _CatalogManagementView(embedded: embedded);
    final body = ref.watch(catalogProvider).when(
          loading: () => const AppLoadingState(message: 'Cargando servicios'),
          error: (e, _) => AppErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(catalogProvider),
          ),
          data: (items) => _CatalogList(items: items),
        );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios y tarifas')),
      body: body,
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.items});
  final List<CatalogItem> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.where((item) => item.category != 'coin_package').toList();
    if (visible.isEmpty) {
      return const EmptyState(
        icon: Icons.medical_services_outlined,
        title: 'Sin servicios',
        message: 'Los servicios disponibles aparecerán aquí.',
      );
    }
    return AdaptivePage(
      maxWidth: 920,
      children: [
        for (final item in visible)
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.medical_services_rounded, color: AppColors.teal),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (item.description != null)
                        Text(item.description!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusPill(
                  label: _priceLabel(item.chargeMode, item.coinPrice, item.price, item.currency),
                  color: item.chargeMode == 'coins' ? AppColors.teal : AppColors.blue,
                  dense: true,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CatalogManagementView extends ConsumerWidget {
  const _CatalogManagementView({this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = ref.watch(catalogManagementProvider).when(
      loading: () => const AppLoadingState(message: 'Cargando catálogo'),
      error: (e, _) => AppErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(catalogManagementProvider),
      ),
      data: (data) {
        final services = data.services
            .where((service) => service.category != 'coin_package')
            .toList();
        final serviceIds = services.map((service) => service.id).toSet();
        final prices = data.prices
            .where((price) => serviceIds.contains(price.serviceId))
            .toList();
        return AdaptivePage(
          maxWidth: 1180,
          children: [
          SectionHeader(
            title: 'Servicios',
            actionLabel: embedded ? 'Agregar' : null,
            onAction: embedded ? () => _serviceDialog(context, ref) : null,
          ),
          for (final service in services)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.medical_services_outlined),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('${service.code} · ${service.category}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      StatusPill(
                        label: service.isActive ? 'Activo' : 'Inactivo',
                        color: service.isActive ? AppColors.success : AppColors.warning,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final price in prices.where((p) => p.serviceId == service.id))
                        StatusPill(
                          label: _priceLabel(price.chargeMode, price.coinPrice, price.price, price.currency),
                          color: price.chargeMode == 'coins' ? AppColors.teal : AppColors.blue,
                          dense: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _serviceDialog(context, ref, service: service),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar servicio'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _priceDialog(context, ref, service),
                          icon: const Icon(Icons.price_change_outlined),
                          label: const Text('Nueva tarifa'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (embedded) return body;
    return Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de servicios y tarifas'),
          actions: [
            IconButton(
              tooltip: 'Agregar servicio',
              onPressed: () => _serviceDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: body,
      );
  }
  Future<void> _serviceDialog(BuildContext context, WidgetRef ref, {CatalogServiceAdmin? service}) async {
    final code = TextEditingController(text: service?.code ?? '');
    final name = TextEditingController(text: service?.name ?? '');
    final category = TextEditingController(text: service?.category ?? 'consultation');
    final description = TextEditingController(text: service?.description ?? '');
    var active = service?.isActive ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(service == null ? 'Agregar servicio' : 'Editar servicio'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: code, label: 'Código'),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(controller: name, label: 'Nombre'),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(controller: category, label: 'Categoría'),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(controller: description, label: 'Descripción'),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: 420,
              child: AppDialogActions(
                cancelLabel: 'Cancelar',
                confirmLabel: 'Guardar',
                onCancel: () => Navigator.pop(dialogContext, false),
                onConfirm: () => Navigator.pop(dialogContext, true),
                confirmIcon: Icons.save_outlined,
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final repo = ref.read(catalogRepositoryProvider);
    if (service == null) {
      await repo.createService(code: code.text.trim(), name: name.text.trim(), category: category.text.trim(), description: description.text.trim(), isActive: active);
    } else {
      await repo.updateService(id: service.id, code: code.text.trim(), name: name.text.trim(), category: category.text.trim(), description: description.text.trim(), isActive: active);
    }
    ref.invalidate(catalogManagementProvider);
  }

  Future<void> _priceDialog(BuildContext context, WidgetRef ref, CatalogServiceAdmin service) async {
    final amount = TextEditingController();
    var mode = 'fiat';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Agregar tarifa a ${service.name}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'fiat', label: Text('Bs')),
                    ButtonSegment(value: 'coins', label: Text('Monedas')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) => setState(() => mode = value.first),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: amount,
                  label: mode == 'fiat' ? 'Monto en Bs' : 'Monto en monedas',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: 420,
              child: AppDialogActions(
                cancelLabel: 'Cancelar',
                confirmLabel: 'Guardar tarifa',
                onCancel: () => Navigator.pop(dialogContext, false),
                onConfirm: () => Navigator.pop(dialogContext, true),
                confirmIcon: Icons.save_outlined,
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final value = double.tryParse(amount.text.replaceAll(',', '.')) ?? 0;
    await ref.read(catalogRepositoryProvider).createPrice(
          serviceId: service.id,
          chargeMode: mode,
          coinPrice: mode == 'coins' ? value.round() : null,
          price: mode == 'fiat' ? value : null,
          currency: 'BOB',
        );
    ref.invalidate(catalogManagementProvider);
    ref.invalidate(catalogProvider);
  }
}

String _priceLabel(String? mode, int? coinPrice, double? price, String? currency) {
  if (mode == 'coins') return '${coinPrice ?? 0} monedas';
  if (price == null) return 'Tarifa no registrada';
  return NumberFormat.currency(locale: 'es_BO', symbol: '${currency ?? 'Bs'} ', decimalDigits: 2).format(price);
}
