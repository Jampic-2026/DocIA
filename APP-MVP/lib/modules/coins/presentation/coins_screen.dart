import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/authorization/permission_codes.dart';
import '../../../core/responsive/adaptive_page.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../files/application/files_controller.dart';
import '../application/coins_controller.dart';
import '../domain/coin_overview.dart';

class CoinsScreen extends ConsumerStatefulWidget {
  const CoinsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<CoinsScreen> createState() => _CoinsScreenState();
}

class _CoinsScreenState extends ConsumerState<CoinsScreen>
    with WidgetsBindingObserver {
  String? _buyingPackageId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCoins());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refreshCoins(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCoins();
    }
  }

  void _refreshCoins() {
    if (!mounted) return;
    ref.invalidate(coinOverviewProvider);
  }

  @override
  Widget build(BuildContext context) {
    final canManage =
        ref.watch(authControllerProvider).user?.can(PermissionCodes.coinsManage) ??
            false;
    final body = ref.watch(coinOverviewProvider).when(
          loading: () => const AppLoadingState(message: 'Cargando monedas'),
          error: (e, _) => AppErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(coinOverviewProvider),
          ),
          data: (data) => canManage ? _adminPackages(data.packages, ref) : _patientCoins(data),
        );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(canManage ? 'Gestión de paquetes de monedas' : 'Monedas Doc IA'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Agregar paquete',
              onPressed: () => _packageDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _adminPackages(List<CoinPackage> packages, WidgetRef ref) => AdaptivePage(
        maxWidth: 920,
        children: [
          SectionHeader(
            title: 'Paquetes disponibles',
            subtitle: 'El administrador define montos y precios; no compra paquetes desde esta cuenta.',
            actionLabel: 'Agregar',
            onAction: () => _packageDialog(context, ref),
          ),
          if (packages.isEmpty)
            const EmptyState(
              icon: Icons.toll_outlined,
              title: 'Sin paquetes',
              message: 'Agrega el primer paquete de monedas.',
            )
          else
            for (final item in packages)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final summary = Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.toll_rounded, color: AppColors.teal),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    '${item.code ?? 'SIN_CODIGO'} · ${item.coinAmount} monedas'
                                    '${item.bonusCoinAmount > 0 ? ' + ${item.bonusCoinAmount} bono' : ''}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                        final status = StatusPill(
                          label: item.isActive ? 'Activo' : 'Inactivo',
                          color: item.isActive ? AppColors.success : AppColors.warning,
                          dense: true,
                        );
                        if (constraints.maxWidth < 520) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              summary,
                              const SizedBox(height: AppSpacing.sm),
                              status,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: summary),
                            const SizedBox(width: AppSpacing.md),
                            status,
                          ],
                        );
                      },
                    ),
                    if (item.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        item.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (item.qrImageUrl?.isNotEmpty ?? false) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _QrPreviewBox(fileUrl: item.qrImageUrl),
                          const SizedBox(width: AppSpacing.md),
                          const Expanded(
                            child: StatusPill(
                              label: 'QR propio configurado',
                              color: AppColors.teal,
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 560;
                        final priceLabel = Text(
                          '${item.currency} ${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        );
                        final edit = OutlinedButton.icon(
                          onPressed: () => _packageDialog(context, ref, package: item),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        );
                        final delete = OutlinedButton.icon(
                          onPressed: item.isActive ? () => _deletePackage(context, ref, item) : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Eliminar'),
                        );
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              priceLabel,
                              const SizedBox(height: AppSpacing.sm),
                              edit,
                              const SizedBox(height: AppSpacing.sm),
                              delete,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: priceLabel),
                            SizedBox(width: 160, child: edit),
                            const SizedBox(width: AppSpacing.md),
                            SizedBox(width: 160, child: delete),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
        ],
      );

  Widget _patientCoins(CoinOverview data) => AdaptivePage(
        maxWidth: 920,
        children: [
          AppCard(
            color: AppColors.teal,
            child: Column(
              children: [
                const Icon(Icons.toll_rounded, color: AppColors.white, size: 36),
                Text(
                  '${data.availableBalance}',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text('Saldo disponible', style: TextStyle(color: AppColors.white70)),
              ],
            ),
          ),
          const SectionHeader(title: 'Paquetes disponibles'),
          if (data.packages.isEmpty)
            const AppCard(child: Text('No existen paquetes disponibles.'))
          else
            for (final item in data.packages)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        (item.qrImageUrl?.isNotEmpty ?? false)
                            ? _QrPreviewBox(fileUrl: item.qrImageUrl)
                            : const Icon(Icons.toll_rounded, color: AppColors.teal),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${item.coinAmount} monedas${item.bonusCoinAmount > 0 ? ' + ${item.bonusCoinAmount} de bono' : ''}'),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${item.currency} ${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _buyingPackageId == null ? () => _buy(item.id) : null,
                        icon: _buyingPackageId == item.id
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.shopping_cart_outlined),
                        label: Text(_buyingPackageId == item.id ? 'Creando orden' : 'Comprar paquete'),
                      ),
                    ),
                  ],
                ),
              ),
          const SectionHeader(title: 'Movimientos recientes'),
          if (data.transactions.isEmpty)
            const AppCard(child: Text('Aún no tienes movimientos.'))
          else
            for (final item in data.transactions)
              ListTile(
                leading: Icon(
                  item.amount > 0 ? Icons.add_circle : Icons.remove_circle,
                  color: item.amount > 0 ? AppColors.success : AppColors.danger,
                ),
                title: Text(item.reason ?? item.type),
                trailing: Text('${item.amount > 0 ? '+' : ''}${item.amount}'),
              ),
        ],
      );

  Future<void> _packageDialog(BuildContext context, WidgetRef ref, {CoinPackage? package}) async {
    final code = TextEditingController(text: package?.code ?? '');
    final name = TextEditingController(text: package?.name ?? '');
    final description = TextEditingController(text: package?.description ?? '');
    final coins = TextEditingController(text: package?.coinAmount.toString() ?? '');
    final bonus = TextEditingController(text: package?.bonusCoinAmount.toString() ?? '0');
    final price = TextEditingController(text: package?.price.toStringAsFixed(2) ?? '');
    String? qrImageUrl = package?.qrImageUrl;
    XFile? selectedQr;
    Uint8List? selectedQrBytes;
    var active = package?.isActive ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(package == null ? 'Agregar paquete' : 'Editar paquete'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(controller: code, label: 'Código'),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(controller: name, label: 'Nombre'),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(controller: description, label: 'Descripción'),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: coins,
                    label: 'Monedas',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: bonus,
                    label: 'Bono',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: price,
                    label: 'Precio Bs',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (selectedQrBytes != null || (qrImageUrl?.isNotEmpty ?? false)) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _QrPreviewBox(
                        fileUrl: qrImageUrl,
                        bytes: selectedQrBytes,
                        fileName: selectedQr?.name,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 95,
                      );
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setState(() {
                          selectedQr = picked;
                          selectedQrBytes = bytes;
                        });
                      }
                    },
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: Text(
                      selectedQr?.name ??
                          ((qrImageUrl?.isNotEmpty ?? false)
                              ? 'Editar imagen QR del paquete'
                              : 'Agregar imagen QR del paquete'),
                    ),
                  ),
                  if (selectedQr != null || (qrImageUrl?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedQr?.name ?? 'QR propio configurado',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            selectedQr = null;
                            selectedQrBytes = null;
                            qrImageUrl = '';
                          }),
                          child: const Text('Quitar'),
                        ),
                      ],
                    ),
                  ],
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo'),
                    value: active,
                    onChanged: (value) => setState(() => active = value),
                  ),
                ],
              ),
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
    if (selectedQr != null && selectedQrBytes != null) {
      final stored = await ref.read(filesRepositoryProvider).upload(
            bytes: selectedQrBytes!,
            fileName: selectedQr!.name,
            category: 'payment-qr',
          );
      qrImageUrl = stored.fileUrl;
    }
    final repo = ref.read(coinsRepositoryProvider);
    final payload = (
      code: code.text.trim(),
      name: name.text.trim(),
      description: description.text.trim(),
      coinAmount: int.tryParse(coins.text.trim()) ?? 0,
      bonusCoinAmount: int.tryParse(bonus.text.trim()) ?? 0,
      price: double.tryParse(price.text.trim().replaceAll(',', '.')) ?? 0,
      currency: 'BOB',
      isActive: active,
    );
    if (package == null) {
      await repo.createPackage(code: payload.code, name: payload.name, description: payload.description, qrImageUrl: qrImageUrl, coinAmount: payload.coinAmount, bonusCoinAmount: payload.bonusCoinAmount, price: payload.price, currency: payload.currency, isActive: payload.isActive);
    } else {
      await repo.updatePackage(id: package.id, code: payload.code, name: payload.name, description: payload.description, qrImageUrl: qrImageUrl, coinAmount: payload.coinAmount, bonusCoinAmount: payload.bonusCoinAmount, price: payload.price, currency: payload.currency, isActive: payload.isActive);
    }
    ref.invalidate(coinOverviewProvider);
  }

  Future<void> _deletePackage(
    BuildContext context,
    WidgetRef ref,
    CoinPackage package,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar paquete'),
        content: Text(
          '${package.name} dejará de estar disponible para nuevas compras.',
        ),
        actions: [
          SizedBox(
            width: 420,
            child: AppDialogActions(
              cancelLabel: 'Cancelar',
              confirmLabel: 'Eliminar',
              onCancel: () => Navigator.pop(dialogContext, false),
              onConfirm: () => Navigator.pop(dialogContext, true),
              confirmIcon: Icons.delete_outline_rounded,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(coinsRepositoryProvider).deletePackage(package.id);
    ref.invalidate(coinOverviewProvider);
  }

  Future<void> _buy(String packageId) async {
    setState(() => _buyingPackageId = packageId);
    try {
      await ref.read(coinsRepositoryProvider).purchase(packageId);
      ref.invalidate(coinOverviewProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orden creada. Continúa el pago con tarjeta o QR.')),
      );
      if (MediaQuery.sizeOf(context).width >= AppDimensions.compactBreakpoint) {
        final currentPath = GoRouterState.of(context).uri.path;
        final basePath = currentPath.endsWith('/coins')
            ? currentPath.substring(0, currentPath.length - '/coins'.length)
            : AppRoutes.patientProfile;
        context.push('$basePath/payments');
      } else {
        context.pushNamed(AppRoutes.payments);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _buyingPackageId = null);
    }
  }
}

class _QrPreviewBox extends StatelessWidget {
  const _QrPreviewBox({
    this.fileUrl,
    this.bytes,
    this.fileName,
  });

  static const double _size = 96;

  final String? fileUrl;
  final Uint8List? bytes;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
      ),
      child: AppSignedImage(
        fileUrl: fileUrl,
        bytes: bytes,
        width: _size,
        height: _size,
        fit: BoxFit.contain,
        fallbackIcon: Icons.qr_code_2_rounded,
        fallbackColor: AppColors.teal,
        enablePreview: true,
        previewTitle: fileName ?? 'Código QR del paquete',
      ),
    );
  }
}
