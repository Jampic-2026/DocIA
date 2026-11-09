import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/config/build_config.dart';
import '../../../core/authorization/permission_codes.dart';
import '../../../core/responsive/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../coins/application/coins_controller.dart';
import '../../files/application/files_controller.dart';
import '../../admin_console/application/admin_console_controller.dart';
import '../application/payments_controller.dart';
import '../domain/payment_record.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen>
    with WidgetsBindingObserver {
  final Set<String> _processingOrders = <String>{};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPaymentState());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshPaymentState(),
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
      _refreshPaymentState();
    }
  }

  void _refreshPaymentState() {
    if (!mounted) return;
    ref.invalidate(paymentOrdersProvider);
    ref.invalidate(paymentHistoryProvider);
    ref.invalidate(paymentReviewQueueProvider);
    ref.invalidate(paymentConfigurationProvider);
    ref.invalidate(coinOverviewProvider);
  }

  @override
  Widget build(BuildContext context) {
    final canManage =
        ref
            .watch(authControllerProvider)
            .user
            ?.can(PermissionCodes.paymentsManage) ??
        false;
    if (canManage) {
      if (widget.embedded) return _reviewQueue(ref);
      return Scaffold(
        appBar: AppBar(title: const Text('Validación de pagos')),
        body: _reviewQueue(ref),
      );
    }
    if (widget.embedded) {
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Órdenes'),
                Tab(text: 'Historial'),
              ],
            ),
            Expanded(
              child: TabBarView(children: [_orders(ref), _history(ref)]),
            ),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pagos'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Órdenes'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: TabBarView(children: [_orders(ref), _history(ref)]),
      ),
    );
  }

  Widget _reviewQueue(WidgetRef ref) {
    return ref
        .watch(paymentReviewQueueProvider)
        .when(
          loading: () =>
              const AppLoadingState(message: 'Cargando comprobantes'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(paymentReviewQueueProvider),
          ),
          data: (items) {
            final manualReceipts = items
                .where(
                  (item) =>
                      item.method == 'qr' || item.method == 'bank_transfer',
                )
                .toList();
            final pendingReceipts = manualReceipts
                .where((item) => item.status == 'pending_validation')
                .toList();
            final reviewedReceipts = manualReceipts
                .where((item) => item.status != 'pending_validation')
                .toList();
            return AdaptivePage(
              maxWidth: 980,
              children: [
                _generalQrSettingsCard(ref),
                const SectionHeader(
                  title: 'Comprobantes pendientes',
                  subtitle:
                      'Sólo se revisan pagos manuales por QR o transferencia.',
                ),
                if (pendingReceipts.isEmpty)
                  const EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'Sin comprobantes pendientes',
                    message:
                        'Los pagos QR enviados por usuarios aparecerán aquí.',
                  )
                else
                  for (final payment in pendingReceipts)
                    _AdminPaymentReceiptCard(
                      payment: payment,
                      onOpenReceipt: () => _openReceipt(payment),
                      onReject: () => _reviewPayment(payment, approved: false),
                      onApprove: () => _reviewPayment(payment, approved: true),
                    ),
                const SectionHeader(
                  title: 'Historial de comprobantes',
                  subtitle: 'Comprobantes QR ya aprobados o rechazados.',
                ),
                if (reviewedReceipts.isEmpty)
                  const AppCard(
                    child: Text('Aún no hay comprobantes revisados.'),
                  )
                else
                  for (final payment in reviewedReceipts)
                    _AdminPaymentReceiptCard(
                      payment: payment,
                      onOpenReceipt: () => _openReceipt(payment),
                    ),
              ],
            );
          },
        );
  }

  Widget _generalQrSettingsCard(WidgetRef ref) {
    final configuration = ref.watch(paymentConfigurationProvider);
    return configuration.when(
      loading: () =>
          const AppCard(child: AppLoadingState(message: 'Cargando QR general')),
      error: (error, _) => AppCard(
        child: AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(paymentConfigurationProvider),
        ),
      ),
      data: (config) => AppCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final qr = config.qrImageUrl?.trim();
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QR general de pagos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Se usa para servicios, citas y otros cobros manuales. Los paquetes de monedas usan el QR configurado en cada paquete.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (config.qrBankName?.trim().isNotEmpty ?? false)
                  Text('Banco: ${config.qrBankName!.trim()}'),
                if (config.qrAccountName?.trim().isNotEmpty ?? false)
                  Text('Titular: ${config.qrAccountName!.trim()}'),
                if (qr == null || qr.isEmpty)
                  const StatusPill(
                    label: 'Sin QR configurado',
                    color: AppColors.warning,
                    dense: true,
                  ),
              ],
            );
            final preview = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vista previa',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: 112,
                  height: 112,
                  child: AppSignedImage(
                    fileUrl: qr,
                    width: 112,
                    height: 112,
                    fallbackIcon: Icons.qr_code_2_rounded,
                    fallbackColor: AppColors.teal,
                    enablePreview: qr != null && qr.isNotEmpty,
                    previewTitle: 'QR general de pagos',
                  ),
                ),
              ],
            );
            final editButton = SizedBox(
              width: constraints.maxWidth < 520 ? double.infinity : 180,
              child: OutlinedButton.icon(
                onPressed: () => _editGeneralQr(context, ref, config),
                icon: const Icon(Icons.edit_outlined),
                label: Text(qr == null || qr.isEmpty ? 'Configurar' : 'Editar'),
              ),
            );

            if (constraints.maxWidth < 620) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      preview,
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  editButton,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                preview,
                const SizedBox(width: AppSpacing.md),
                Expanded(child: details),
                const SizedBox(width: AppSpacing.md),
                editButton,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editGeneralQr(
    BuildContext context,
    WidgetRef ref,
    PaymentConfiguration config,
  ) async {
    final bank = TextEditingController(text: config.qrBankName ?? '');
    final account = TextEditingController(text: config.qrAccountName ?? '');
    String? qrImageUrl = config.qrImageUrl;
    XFile? selectedQr;
    Uint8List? selectedQrBytes;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('QR general de pagos'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Este QR se muestra en servicios, citas y otros cobros manuales. No reemplaza el QR individual de los paquetes de monedas.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Vista previa',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: SizedBox(
                      width: 160,
                      height: 160,
                      child: AppSignedImage(
                        fileUrl: qrImageUrl,
                        bytes: selectedQrBytes,
                        width: 160,
                        height: 160,
                        fallbackIcon: Icons.qr_code_2_rounded,
                        fallbackColor: AppColors.teal,
                        enablePreview:
                            selectedQrBytes != null ||
                            (qrImageUrl?.trim().isNotEmpty ?? false),
                        previewTitle: selectedQr?.name ?? 'QR general de pagos',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 95,
                      );
                      if (picked == null) return;
                      final bytes = await picked.readAsBytes();
                      setDialogState(() {
                        selectedQr = picked;
                        selectedQrBytes = bytes;
                      });
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      selectedQr?.name ??
                          ((qrImageUrl?.trim().isNotEmpty ?? false)
                              ? 'Editar imagen QR'
                              : 'Agregar imagen QR'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(controller: bank, label: 'Banco'),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(controller: account, label: 'Titular de cuenta'),
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
                confirmIcon: Icons.save_outlined,
                onCancel: () => Navigator.pop(dialogContext, false),
                onConfirm: () => Navigator.pop(dialogContext, true),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != true) {
      bank.dispose();
      account.dispose();
      return;
    }
    if (selectedQr != null && selectedQrBytes != null) {
      final stored = await ref
          .read(filesRepositoryProvider)
          .upload(
            bytes: selectedQrBytes!,
            fileName: selectedQr!.name,
            category: 'payment-qr',
          );
      qrImageUrl = stored.fileUrl;
    }
    await ref
        .read(adminConsoleRepositoryProvider)
        .updateSetting(
          'payments.qr_image_url',
          qrImageUrl?.trim() ?? '',
          description:
              'QR general para servicios, citas y otros cobros manuales.',
        );
    await ref
        .read(adminConsoleRepositoryProvider)
        .updateSetting(
          'payments.qr_bank_name',
          bank.text.trim(),
          description: 'Banco del QR general de pagos.',
        );
    await ref
        .read(adminConsoleRepositoryProvider)
        .updateSetting(
          'payments.qr_account_name',
          account.text.trim(),
          description: 'Titular del QR general de pagos.',
        );
    bank.dispose();
    account.dispose();
    ref.invalidate(paymentConfigurationProvider);
    ref.invalidate(systemSettingsProvider);
  }

  Future<void> _openReceipt(PaymentRecord payment) async {
    final receiptUrl = payment.receiptUrl;
    if (receiptUrl == null || receiptUrl.isEmpty) return;
    final uri = Uri.tryParse(receiptUrl);
    final isPdf = uri?.path.toLowerCase().endsWith('.pdf') ?? false;
    final isImage = RegExp(
      r'\.(png|jpe?g|webp|gif)(\?.*)?$',
      caseSensitive: false,
    ).hasMatch(receiptUrl);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Comprobante de pago',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: isImage
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final side = constraints.biggest.shortestSide.clamp(
                              260.0,
                              520.0,
                            );
                            return Center(
                              child: SizedBox(
                                width: side,
                                height: side,
                                child: AppSignedImage(
                                  fileUrl: receiptUrl,
                                  width: side,
                                  height: side,
                                  fit: BoxFit.contain,
                                  enablePreview: true,
                                  previewTitle: 'Comprobante de pago',
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPdf
                                    ? Icons.picture_as_pdf_outlined
                                    : Icons.insert_drive_file_outlined,
                                size: 54,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SelectableText(
                                receiptUrl,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: uri == null
                      ? null
                      : () async {
                          try {
                            final signed = await ref
                                .read(filesRepositoryProvider)
                                .accessUrl(receiptUrl);
                            final target = Uri.tryParse(signed);
                            if (target != null) {
                              await launchUrl(
                                target,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          } catch (_) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(isPdf ? 'Abrir PDF' : 'Abrir comprobante'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reviewPayment(
    PaymentRecord payment, {
    required bool approved,
  }) async {
    String? reason;
    if (!approved) {
      var reasonDraft = '';
      var showReasonError = false;
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final trimmed = reasonDraft.trim();
              if (trimmed.length < 3) {
                setDialogState(() => showReasonError = true);
                return;
              }
              Navigator.pop(dialogContext, trimmed);
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Rechazar pago',
                        style: Theme.of(dialogContext).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'Motivo',
                        maxLines: 1,
                        onChanged: (value) {
                          reasonDraft = value;
                          if (showReasonError && value.trim().length >= 3) {
                            setDialogState(() => showReasonError = false);
                          }
                        },
                        onFieldSubmitted: (_) => submit(),
                      ),
                      if (showReasonError) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Ingresa un motivo de al menos 3 caracteres.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      AppDialogActions(
                        cancelLabel: 'Cancelar',
                        confirmLabel: 'Rechazar',
                        onCancel: () => Navigator.pop(dialogContext),
                        onConfirm: submit,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      if (reason == null || reason.trim().length < 3) return;
    }
    try {
      await ref
          .read(paymentsRepositoryProvider)
          .reviewPayment(payment.id, approved: approved, reason: reason);
      _refreshPaymentState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Pago aprobado.' : 'Pago rechazado.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _orders(WidgetRef ref) {
    final configuration = ref.watch(paymentConfigurationProvider);
    return ref
        .watch(paymentOrdersProvider)
        .when(
          loading: () =>
              const AppLoadingState(message: 'Cargando órdenes de pago'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(paymentOrdersProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Sin órdenes de pago',
                  message:
                      'Los cobros generados por tus servicios aparecerán aquí.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _PaymentOrderCard(
                      order: items[index],
                      isProcessing: _processingOrders.contains(items[index].id),
                      onPayWithCard:
                          _canPayWithCard(
                            items[index],
                            configuration.valueOrNull,
                          )
                          ? () => _payWithCard(items[index])
                          : null,
                      onSubmitQr:
                          _canSubmitQr(items[index]) &&
                              (_qrForOrder(
                                    items[index],
                                    configuration.valueOrNull,
                                  ) !=
                                  null)
                          ? () => _submitQr(
                              items[index],
                              configuration.valueOrNull,
                            )
                          : null,
                      qrUnavailable:
                          _canSubmitQr(items[index]) &&
                          !configuration.isLoading &&
                          _qrForOrder(
                                items[index],
                                configuration.valueOrNull,
                              ) ==
                              null,
                    ),
                  ),
                ),
        );
  }

  Widget _history(WidgetRef ref) {
    return ref
        .watch(paymentHistoryProvider)
        .when(
          loading: () => const AppLoadingState(message: 'Cargando tus pagos'),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(paymentHistoryProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.payments_outlined,
                  title: 'Sin pagos registrados',
                  message: 'Tu historial de transacciones aparecerá aquí.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  itemBuilder: (_, index) =>
                      _PaymentHistoryTile(payment: items[index]),
                ),
        );
  }

  bool _canPayWithCard(
    PaymentOrder order,
    PaymentConfiguration? configuration,
  ) {
    if (BuildConfig.stripePublishableKey.isEmpty) return false;
    if (configuration?.stripeEnabled != true) return false;
    if (_hasPaymentInValidation(order)) return false;
    return order.chargeMode == 'fiat' &&
        order.amount != null &&
        <String>{
          'pending',
          'accepted',
          'rejected',
          'failed',
        }.contains(order.status) &&
        order.latestPaymentStatus != 'paid';
  }

  bool _canSubmitQr(PaymentOrder order) {
    if (_hasPaymentInValidation(order)) return false;
    return order.chargeMode == 'fiat' &&
        order.amount != null &&
        <String>{'pending', 'accepted', 'rejected'}.contains(order.status) &&
        order.latestPaymentStatus != 'paid';
  }

  bool _hasPaymentInValidation(PaymentOrder order) {
    return order.status == 'pending_validation' ||
        order.latestPaymentStatus == 'pending_validation';
  }

  String? _qrForOrder(PaymentOrder order, PaymentConfiguration? configuration) {
    final packageQr = order.qrImageUrl?.trim();
    if (packageQr != null && packageQr.isNotEmpty) return packageQr;
    if (order.relatedEntityType == 'coin_package') return null;
    final globalQr = configuration?.qrImageUrl?.trim();
    if (globalQr != null && globalQr.isNotEmpty) return globalQr;
    return null;
  }

  Future<void> _submitQr(
    PaymentOrder order,
    PaymentConfiguration? configuration,
  ) async {
    _PickedReceipt? receipt;
    final qrImageUrl = _qrForOrder(order, configuration);
    final qrBankName = configuration?.qrBankName?.trim();
    final qrAccountName = configuration?.qrAccountName?.trim();
    if (qrImageUrl == null) return;
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Pago por QR'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${order.currency} ${order.amount?.toStringAsFixed(2) ?? '0.00'}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (qrBankName?.isNotEmpty ?? false) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(qrBankName!),
                    ],
                    if (qrAccountName?.isNotEmpty ?? false)
                      Text(qrAccountName!),
                    const SizedBox(height: AppSpacing.md),
                    _PaymentQrImage(fileUrl: qrImageUrl),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickReceiptSource(
                            dialogContext,
                          );
                          if (picked != null) {
                            setDialogState(() => receipt = picked);
                          }
                        },
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(
                          receipt?.name ??
                              'Seleccionar imagen o PDF del comprobante',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              SizedBox(
                width: 520,
                child: AppDialogActions(
                  cancelLabel: 'Cancelar',
                  confirmLabel: 'Enviar',
                  onCancel: () => Navigator.pop(dialogContext, false),
                  onConfirm: receipt == null
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Selecciona una imagen o PDF del comprobante.',
                              ),
                            ),
                          );
                        }
                      : () => Navigator.pop(dialogContext, true),
                ),
              ),
            ],
          ),
        ),
      );
      if (submitted != true || receipt == null) return;
      setState(() => _processingOrders.add(order.id));
      final stored = await ref
          .read(filesRepositoryProvider)
          .upload(
            bytes: receipt!.bytes,
            fileName: receipt!.name,
            category: 'payment-receipts',
          );
      await ref
          .read(paymentsRepositoryProvider)
          .submitQrPayment(
            order.id,
            amount: order.amount ?? 0,
            receiptUrl: stored.fileUrl,
          );
      _refreshPaymentState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comprobante enviado. El pago queda en validación.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processingOrders.remove(order.id));
    }
  }

  Future<_PickedReceipt?> _pickReceiptSource(BuildContext dialogContext) async {
    final source = await showModalBottomSheet<String>(
      context: dialogContext,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Imagen desde galería'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF desde archivos del dispositivo'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (source == 'image') {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (image == null) return null;
      return _PickedReceipt(name: image.name, bytes: await image.readAsBytes());
    }
    if (source == 'pdf') {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        dialogTitle: 'Seleccionar PDF del dispositivo',
      );
      final file = picked?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return null;
      return _PickedReceipt(name: file.name, bytes: bytes);
    }
    return null;
  }

  Future<void> _payWithCard(PaymentOrder order) async {
    setState(() => _processingOrders.add(order.id));
    try {
      if (kIsWeb) {
        final session = await ref
            .read(paymentsRepositoryProvider)
            .createStripeCheckoutSession(order.id);
        final launched = await launchUrl(
          Uri.parse(session.url),
          webOnlyWindowName: '_self',
        );
        if (!launched) {
          throw Exception('No se pudo abrir Stripe Checkout.');
        }
        return;
      }
      final intent = await ref
          .read(paymentsRepositoryProvider)
          .createStripePaymentIntent(order.id);
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          merchantDisplayName: 'Doc IA',
          style: ThemeMode.system,
          billingDetails: const BillingDetails(
            address: Address(
              country: 'BO',
              city: null,
              line1: null,
              line2: null,
              postalCode: null,
              state: null,
            ),
          ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      await ref
          .read(paymentsRepositoryProvider)
          .syncStripePaymentIntent(intent.paymentIntentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago procesado correctamente.')),
      );
      _refreshPaymentState();
    } on StripeException catch (error) {
      final message = error.error.localizedMessage ?? 'Pago cancelado.';
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processingOrders.remove(order.id));
    }
  }
}

class _PickedReceipt {
  const _PickedReceipt({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

class _AdminPaymentReceiptCard extends StatelessWidget {
  const _AdminPaymentReceiptCard({
    required this.payment,
    required this.onOpenReceipt,
    this.onReject,
    this.onApprove,
  });

  final PaymentRecord payment;
  final VoidCallback onOpenReceipt;
  final VoidCallback? onReject;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final status = _paymentStatus(payment.status);
    final hasActions = onReject != null || onApprove != null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.qr_code_2_rounded),
            title: Text(payment.concept),
            subtitle: Text(
              '${_methodLabel(payment.method)} · ${payment.currency} ${payment.amount.toStringAsFixed(2)}'
              '${payment.transactionReference == null ? '' : ' · Ref. ${payment.transactionReference}'}',
            ),
            trailing: StatusPill(
              label: status.$1,
              color: status.$2,
              dense: true,
            ),
          ),
          if (payment.rejectionReason?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Motivo: ${payment.rejectionReason}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (payment.receiptUrl?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onOpenReceipt,
              icon: const Icon(Icons.open_in_full_rounded),
              label: const Text('Ver comprobante'),
            ),
          ],
          if (hasActions) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aprobar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentQrImage extends StatelessWidget {
  const _PaymentQrImage({required this.fileUrl});

  final String fileUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth.clamp(280.0, 420.0);
        return Center(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.15)),
            ),
            child: AppSignedImage(
              fileUrl: fileUrl,
              width: side,
              height: side,
              fit: BoxFit.contain,
              fallbackIcon: Icons.qr_code_2_rounded,
              fallbackColor: AppColors.teal,
              enablePreview: true,
              previewTitle: 'Código QR para el pago',
            ),
          ),
        );
      },
    );
  }
}

class _PaymentOrderCard extends StatelessWidget {
  const _PaymentOrderCard({
    required this.order,
    required this.isProcessing,
    this.onPayWithCard,
    this.onSubmitQr,
    this.qrUnavailable = false,
  });

  final PaymentOrder order;
  final bool isProcessing;
  final VoidCallback? onPayWithCard;
  final VoidCallback? onSubmitQr;
  final bool qrUnavailable;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = order.latestPaymentStatus == 'pending_validation'
        ? 'pending_validation'
        : order.status;
    final status = _paymentStatus(effectiveStatus);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  order.concept,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill(label: status.$1, color: status.$2, dense: true),
            ],
          ),
          if (order.serviceName case final name?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(name),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            order.chargeMode == 'coins'
                ? '${order.coinAmount ?? 0} monedas Doc IA'
                : '${order.currency} ${order.amount?.toStringAsFixed(2) ?? '0.00'}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (order.dueAt case final dueAt?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Vence: ${dueAt.day}/${dueAt.month}/${dueAt.year}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (order.latestPaymentStatus case final paymentStatus?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Último intento: ${_paymentStatus(paymentStatus).$1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (order.latestPaymentStatus == 'rejected' &&
              (order.latestPaymentRejectionReason?.trim().isNotEmpty ??
                  false)) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Motivo del rechazo: ${order.latestPaymentRejectionReason!.trim()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (effectiveStatus == 'pending_validation') ...[
            const SizedBox(height: AppSpacing.md),
            const StatusPill(
              label: 'Comprobante enviado, pendiente de validación',
              color: AppColors.warning,
            ),
          ],
          if (onPayWithCard != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isProcessing ? null : onPayWithCard,
                icon: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.credit_card_outlined),
                label: Text(isProcessing ? 'Procesando' : 'Pagar con tarjeta'),
              ),
            ),
          ],
          if (onSubmitQr != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isProcessing ? null : onSubmitQr,
                icon: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_2_rounded),
                label: Text(isProcessing ? 'Enviando' : 'Pagar por QR'),
              ),
            ),
          ] else if (qrUnavailable) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Pago QR no disponible por ahora.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentHistoryTile extends StatelessWidget {
  const _PaymentHistoryTile({required this.payment});

  final PaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final status = _paymentStatus(payment.status);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      leading: CircleAvatar(
        backgroundColor: status.$2.withValues(alpha: 0.14),
        child: Icon(Icons.payments_outlined, color: status.$2),
      ),
      title: Text(payment.concept),
      subtitle: Text(
        '${_methodLabel(payment.method)} · '
        '${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${payment.currency} ${payment.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(status.$1, style: TextStyle(color: status.$2)),
        ],
      ),
    );
  }
}

(String, Color) _paymentStatus(String status) => switch (status) {
  'paid' => ('Pagado', AppColors.success),
  'accepted' => ('Aceptado', AppColors.info),
  'pending_validation' => ('En validación', AppColors.warning),
  'failed' => ('Fallido', AppColors.danger),
  'rejected' => ('Rechazado', AppColors.danger),
  'cancelled' => ('Cancelado', AppColors.danger),
  'expired' => ('Vencido', AppColors.warning),
  'refunded' => ('Reembolsado', AppColors.info),
  'partially_refunded' => ('Reembolso parcial', AppColors.info),
  _ => ('Pendiente', AppColors.warning),
};

String _methodLabel(String method) => switch (method) {
  'qr' => 'QR',
  'cash' => 'Efectivo',
  'card' => 'Tarjeta',
  'bank_transfer' => 'Transferencia bancaria',
  _ => 'Otro',
};
