import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/telemedicine/application/telemedicine_controller.dart';
import '../../../modules/telemedicine/domain/telemedicine_room.dart';
import '../../../modules/appointments/application/appointments_controller.dart';
import '../../../modules/appointments/domain/appointment.dart';
import '../../../modules/auth/application/auth_controller.dart';
import '../../../modules/auth/domain/user_role.dart';
import '../../../modules/integrations/application/integrations_controller.dart';
import '../../../modules/clinical_records/application/clinical_records_controller.dart';
import '../../../modules/files/application/files_controller.dart';

class TelemedicineScreen extends ConsumerWidget {
  const TelemedicineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(telemedicineRoomsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Telemedicina')),
      body: rooms.when(
        loading: () => const AppLoadingState(message: 'Buscando tus salas'),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(telemedicineRoomsProvider),
        ),
        data: (items) => _TelemedicineContent(items: items),
      ),
    );
  }
}

class _TelemedicineContent extends ConsumerWidget {
  const _TelemedicineContent({required this.items});

  final List<TelemedicineRoom> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProfessional =
        ref.watch(authControllerProvider).user?.experience ==
        UserExperience.professional;
    if (!isProfessional && items.isEmpty) {
      return EmptyState(
        icon: Icons.video_call_outlined,
        title: 'No tienes una sala disponible',
        message:
            'La sala se prepara automáticamente para tu cita. Si el proveedor no está disponible, se reintentará.',
        action: OutlinedButton.icon(
          onPressed: () => ref.invalidate(telemedicineRoomsProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualizar'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(googleWorkspaceStatusProvider);
        final _ = await ref.refresh(telemedicineRoomsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (isProfessional) ...[
            _ProfessionalPreparation(existingRooms: items),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Salas preparadas'),
            const SizedBox(height: AppSpacing.md),
          ],
          if (items.isEmpty)
            const AppCard(child: Text('Todavía no existen salas preparadas.'))
          else
            for (final room in items) _RoomCard(room: room),
        ],
      ),
    );
  }
}

class _ProfessionalPreparation extends ConsumerStatefulWidget {
  const _ProfessionalPreparation({required this.existingRooms});

  final List<TelemedicineRoom> existingRooms;

  @override
  ConsumerState<_ProfessionalPreparation> createState() =>
      _ProfessionalPreparationState();
}

class _ProfessionalPreparationState
    extends ConsumerState<_ProfessionalPreparation> {
  String? _creatingAppointmentId;

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(appointmentsControllerProvider);
    final google = ref.watch(googleWorkspaceStatusProvider);
    final roomAppointmentIds = widget.existingRooms
        .map((room) => room.appointmentId)
        .toSet();
    final eligible =
        (appointments.valueOrNull ?? const <Appointment>[])
            .where(
              (appointment) =>
                  appointment.modality == AppointmentModality.telemedicine &&
                  !roomAppointmentIds.contains(appointment.id) &&
                  appointment.status != AppointmentStatus.cancelled &&
                  appointment.status != AppointmentStatus.completed &&
                  appointment.status != AppointmentStatus.noShow,
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Preparar teleconsultas',
          subtitle: 'Crea una sala institucional para cada cita.',
        ),
        const SizedBox(height: AppSpacing.md),
        google.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(googleWorkspaceStatusProvider),
          ),
          data: (status) => AppCard(
            color: (status.connected ? AppColors.success : AppColors.warning)
                .withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(
                  status.connected
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: status.connected
                      ? AppColors.success
                      : AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    status.connected
                        ? 'Google Workspace está listo.'
                        : 'Administración debe conectar Google Workspace.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (appointments.isLoading)
          const AppLoadingState(message: 'Buscando teleconsultas')
        else if (appointments.hasError)
          AppErrorState(
            message: appointments.error.toString(),
            onRetry: () =>
                ref.read(appointmentsControllerProvider.notifier).refresh(),
          )
        else if (eligible.isEmpty)
          const AppCard(
            child: Text('No tienes teleconsultas pendientes de preparar.'),
          )
        else
          for (final appointment in eligible) ...[
            AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.video_call_outlined,
                  color: AppColors.teal,
                ),
                title: Text(appointment.patientName),
                subtitle: Text(
                  DateFormat("dd/MM/yyyy · HH:mm").format(appointment.startAt),
                ),
                trailing: FilledButton(
                  onPressed:
                      google.valueOrNull?.connected != true ||
                          _creatingAppointmentId != null
                      ? null
                      : () => _create(appointment.id),
                  child: Text(
                    _creatingAppointmentId == appointment.id
                        ? 'Creando...'
                        : 'Crear sala',
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  Future<void> _create(String appointmentId) async {
    setState(() => _creatingAppointmentId = appointmentId);
    try {
      await ref.read(telemedicineRepositoryProvider).createRoom(appointmentId);
      ref.invalidate(telemedicineRoomsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sala de Google Meet creada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _creatingAppointmentId = null);
    }
  }
}

class _RoomCard extends ConsumerStatefulWidget {
  const _RoomCard({required this.room});

  final TelemedicineRoom room;

  @override
  ConsumerState<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends ConsumerState<_RoomCard> {
  bool _opening = false;

  Future<void> _join() async {
    setState(() => _opening = true);
    try {
      await ref
          .read(telemedicineRepositoryProvider)
          .registerJoin(widget.room.id);
      final opened = await launchUrl(
        Uri.parse(widget.room.meetingUrl),
        mode: LaunchMode.platformDefault,
      );
      if (!opened) throw Exception('No se pudo abrir Google Meet.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final activity = ref.watch(telemedicineActivityProvider(room.id));
    final date = DateFormat("d 'de' MMMM, HH:mm", 'es_BO').format(room.startAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          children: [
            UserAvatar(name: room.professionalName, radius: 40),
            const SizedBox(height: AppSpacing.md),
            Text(
              room.professionalName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(room.specialty ?? 'Atención médica'),
            const SizedBox(height: AppSpacing.sm),
            Text(date),
            const SizedBox(height: AppSpacing.md),
            StatusPill(
              label: room.status == 'completed'
                  ? 'Teleconsulta finalizada'
                  : 'Sala disponible',
              color: AppColors.success,
              icon: Icons.fiber_manual_record_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _ReadinessItem(
              icon: Icons.videocam_rounded,
              label: 'Google Meet solicitará acceso a tu cámara.',
            ),
            const _ReadinessItem(
              icon: Icons.mic_rounded,
              label: 'Google Meet solicitará acceso a tu micrófono.',
            ),
            const _ReadinessItem(
              icon: Icons.lock_rounded,
              label: 'Ingresa únicamente desde esta cita.',
            ),
            const SizedBox(height: AppSpacing.lg),
            activity.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
              data: (data) => Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group_outlined, color: AppColors.teal),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${data.participants.where((item) => item.joinedAt != null && item.leftAt == null).length} participantes conectados',
                        ),
                      ),
                    ],
                  ),
                  if (data.files.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    for (final file in data.files)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.attach_file_rounded),
                        title: Text(file.fileName ?? file.documentType),
                        onTap: () async {
                          var url = file.fileUrl;
                          if (Uri.parse(url).pathSegments.contains('files')) {
                            url = await ref
                                .read(filesRepositoryProvider)
                                .accessUrl(url);
                          }
                          await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.platformDefault,
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (room.status != 'completed')
              OutlinedButton.icon(
                onPressed: () => _shareDocument(),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Compartir documento clínico'),
              ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _opening || room.status == 'completed'
                    ? null
                    : _join,
                icon: _opening
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_call_rounded),
                label: Text(
                  _opening
                      ? 'Abriendo Google Meet...'
                      : 'Ingresar a la videollamada',
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _leave(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Registrar salida de la sala'),
            ),
            if (room.status != 'completed' &&
                ref.watch(authControllerProvider).user?.experience ==
                    UserExperience.professional)
              TextButton.icon(
                onPressed: () => _close(),
                icon: const Icon(Icons.call_end),
                label: const Text('Finalizar teleconsulta para todos'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _close() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar teleconsulta'),
        content: const Text(
          'Se finalizará la conferencia en Meet. El cierre de la nota clínica se realiza desde la atención.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(telemedicineRepositoryProvider).closeRoom(widget.room.id);
      ref.invalidate(telemedicineRoomsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _leave() async {
    try {
      await ref
          .read(telemedicineRepositoryProvider)
          .registerLeave(widget.room.id);
      ref.invalidate(telemedicineActivityProvider(widget.room.id));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Salida registrada.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _shareDocument() async {
    try {
      final documents = await ref.read(clinicalDocumentsProvider.future);
      if (!mounted) return;
      if (documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes documentos clínicos para compartir.'),
          ),
        );
        return;
      }
      final selected = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (sheetContext) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Selecciona un documento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final document in documents)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(document.fileName ?? document.documentType),
                subtitle: Text(document.documentType),
                onTap: () => Navigator.pop(sheetContext, document.id),
              ),
          ],
        ),
      );
      if (selected == null) return;
      await ref
          .read(telemedicineRepositoryProvider)
          .shareFile(widget.room.id, selected);
      ref.invalidate(telemedicineActivityProvider(widget.room.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _ReadinessItem extends StatelessWidget {
  const _ReadinessItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.teal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
