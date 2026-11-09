import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/emergencies/application/emergencies_controller.dart';
import '../../../modules/clinical_records/application/clinical_records_controller.dart';
import '../../../modules/emergencies/domain/emergency_event.dart';
import '../../../modules/emergencies/domain/emergency_level.dart';
import '../../../modules/consents/presentation/consent_prompt.dart';
import '../../../modules/maps/application/maps_controller.dart';
import '../../../modules/maps/domain/location_preview.dart';
import '../../../modules/maps/presentation/location_map_card.dart';
import '../../../modules/guidance/application/guidance_controller.dart';
import '../../../modules/guidance/presentation/support_calls_screen.dart';

/// Pantalla de emergencias con ubicación real opcional y alternativa manual.
class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key, this.patientId, this.assessmentId});
  final String? patientId;
  final String? assessmentId;

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

enum _EmergencyStage { selecting, dispatched }

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  EmergencyLevel _level = EmergencyLevel.urgent;
  _EmergencyStage _stage = _EmergencyStage.selecting;
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  EmergencyEvent? _event;
  bool _saving = false;
  bool _locating = false;
  LocationPreview? _location;
  double? _latitude;
  double? _longitude;
  String? _locationMessage;
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _restoreActiveEmergency();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshActiveEmergency(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      _event = await ref
          .read(emergenciesRepositoryProvider)
          .create(
            patientId: widget.patientId,
            riskLevel: _level.riskCode,
            description: _descController.text,
            manualAddress: _addressController.text,
            latitude: _latitude,
            longitude: _longitude,
          );
      if (mounted) setState(() => _stage = _EmergencyStage.dispatched);
      if (widget.assessmentId != null) {
        try {
          await ref
              .read(guidanceRepositoryProvider)
              .decision(
                widget.assessmentId!,
                'emergency',
                relatedId: _event!.id,
              );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'La emergencia fue registrada; queda pendiente vincular la orientación.',
                ),
              ),
            );
          }
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergencia médica'),
        backgroundColor: AppColors.danger,
        foregroundColor: AppColors.onColoredHeader,
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
          color: AppColors.onColoredHeader,
        ),
      ),
      body: _stage == _EmergencyStage.selecting
          ? _buildSelecting(context)
          : _buildDispatched(context),
    );
  }

  Widget _buildSelecting(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Ubicación real y vista generada por la API.
        LocationMapCard(
          preview: _location,
          loading: _locating,
          message: _locationMessage,
          onLocate: _locate,
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(
          title: 'Nivel de gravedad',
          subtitle: 'Ayúdanos a priorizar la atención',
        ),
        const SizedBox(height: AppSpacing.md),
        for (final level in EmergencyLevel.values) ...[
          _LevelTile(
            level: level,
            selected: _level == level,
            onTap: () => setState(() => _level = level),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _descController,
          label: '¿Qué está ocurriendo? (opcional)',
          hint: 'Describe brevemente la situación',
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _addressController,
          label: 'Dirección o referencia (opcional)',
          hint: 'Ej.: zona, calle, número o punto de referencia',
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: _saving ? null : _request,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.white,
            disabledForegroundColor: AppColors.white.withValues(alpha: 0.72),
          ),
          icon: const Icon(
            Icons.emergency_share_rounded,
            color: AppColors.white,
          ),
          label: Text(
            _saving ? 'Enviando solicitud...' : 'Solicitar atención inmediata',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            _latitude == null
                ? 'Puedes enviar la solicitud sin GPS e indicar la dirección manualmente.'
                : 'Tu ubicación se compartirá únicamente con el equipo autorizado.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDispatched(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: AppColors.emergencyGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.white,
                size: 56,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Solicitud enviada',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Nivel: ${_level.label}',
                style: const TextStyle(color: AppColors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LocationMapCard(
          preview: _location,
          loading: _locating,
          message: _event?.manualAddress,
          onLocate: _refreshEventLocation,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Row(
            children: [
              UserAvatar(
                name: _event?.assignedTeamName ?? 'Equipo de emergencias',
                gradient: AppColors.emergencyGradient,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _event?.assignedTeamName ?? 'Solicitud en evaluación',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(_statusMessage(_event?.status)),
                  ],
                ),
              ),
              if (_event?.assignedTeamPhone?.isNotEmpty ?? false)
                IconButton.filled(
                  onPressed: _callAssignedTeam,
                  icon: const Icon(Icons.call_rounded),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _TimelineStep(
          label: 'Solicitud recibida',
          done: _statusProgress(_event?.status) > 0,
          active: _statusProgress(_event?.status) == 0,
        ),
        _TimelineStep(
          label: 'Validación y asignación',
          done: _statusProgress(_event?.status) > 1,
          active: _statusProgress(_event?.status) == 1,
        ),
        _TimelineStep(
          label: 'En camino a tu ubicación',
          done: _statusProgress(_event?.status) > 2,
          active: _statusProgress(_event?.status) == 2,
        ),
        _TimelineStep(
          label: 'Atención en sitio',
          done: _statusProgress(_event?.status) > 3,
          active: _statusProgress(_event?.status) == 3,
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: _event == null ? null : _cancel,
          child: const Text('Cancelar solicitud'),
        ),
        if (_event != null && widget.patientId == null)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SupportCallsScreen(
                  patientMode: true,
                  emergencyId: _event!.id,
                ),
              ),
            ),
            icon: const Icon(Icons.support_agent),
            label: const Text('Solicitar apoyo por Meet'),
          ),
      ],
    );
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      final accepted = await ensureConsentAccepted(
        context: context,
        ref: ref,
        code: 'geolocation',
        serviceName: 'el uso de tu ubicación',
      );
      if (!accepted) {
        if (mounted) {
          setState(() {
            _locationMessage =
                'No compartiremos tu ubicación sin tu autorización. '
                'También puedes escribir una dirección manualmente.';
          });
        }
        return;
      }
      final position = await ref.read(deviceLocationServiceProvider).current();
      _latitude = position.latitude;
      _longitude = position.longitude;
      final preview = await ref
          .read(mapsRepositoryProvider)
          .preview(latitude: position.latitude, longitude: position.longitude);
      if (preview.address?.isNotEmpty ?? false) {
        _addressController.text = preview.address!;
      }
      if (mounted) setState(() => _location = preview);
    } catch (error) {
      if (mounted) setState(() => _locationMessage = error.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _restoreActiveEmergency() async {
    await _refreshActiveEmergency(showErrors: true);
  }

  Future<void> _refreshActiveEmergency({bool showErrors = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final targetId =
          widget.patientId ??
          (await ref.read(clinicalProfileProvider.future)).patientId;
      final events = await ref.read(emergenciesRepositoryProvider).list();
      EmergencyEvent? active;
      for (final event in events) {
        if (event.isActive && event.patientId == targetId) {
          active = event;
          break;
        }
      }
      if (!mounted) return;
      if (active == null) {
        if (_event != null) {
          setState(() {
            _event = null;
            _stage = _EmergencyStage.selecting;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La solicitud de emergencia fue finalizada.'),
            ),
          );
        }
        return;
      }
      setState(() {
        _event = active;
        _stage = _EmergencyStage.dispatched;
        _level = _levelFromRisk(active!.riskLevel);
      });
      await _refreshEventLocation();
    } catch (error) {
      if (showErrors && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshEventLocation() async {
    final event = _event;
    if (event?.latitude == null || event?.longitude == null || _locating) {
      return;
    }
    setState(() => _locating = true);
    try {
      final preview = await ref
          .read(mapsRepositoryProvider)
          .preview(latitude: event!.latitude!, longitude: event.longitude!);
      if (mounted) setState(() => _location = preview);
    } catch (error) {
      if (mounted) setState(() => _locationMessage = error.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _callAssignedTeam() async {
    final phone = _event?.assignedTeamPhone?.trim();
    if (phone == null || phone.isEmpty) return;
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar la llamada.')),
      );
    }
  }

  Future<void> _cancel() async {
    try {
      await ref.read(emergenciesRepositoryProvider).cancel(_event!.id);
      if (mounted) {
        setState(() {
          _event = null;
          _stage = _EmergencyStage.selecting;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

EmergencyLevel _levelFromRisk(String riskLevel) => switch (riskLevel) {
  'green' => EmergencyLevel.low,
  'yellow' => EmergencyLevel.moderate,
  _ => EmergencyLevel.urgent,
};

extension _EmergencyLevelPresentation on EmergencyLevel {
  String get label => switch (this) {
    EmergencyLevel.critical => 'Crítica',
    EmergencyLevel.urgent => 'Urgente',
    EmergencyLevel.moderate => 'Moderada',
    EmergencyLevel.low => 'Leve',
  };

  String get description => switch (this) {
    EmergencyLevel.critical => 'Riesgo vital, atención inmediata',
    EmergencyLevel.urgent => 'Requiere atención prioritaria',
    EmergencyLevel.moderate => 'Atención en el corto plazo',
    EmergencyLevel.low => 'Orientación o seguimiento',
  };

  Color get color => switch (this) {
    EmergencyLevel.critical => AppColors.danger,
    EmergencyLevel.urgent => AppColors.urgent,
    EmergencyLevel.moderate => AppColors.warning,
    EmergencyLevel.low => AppColors.success,
  };
}

int _statusProgress(String? status) => switch (status) {
  'received' => 0,
  'confirming' || 'validating' || 'assigned' => 1,
  'on_route' => 2,
  'on_site' || 'in_care' || 'referred' || 'closed' => 3,
  _ => 0,
};

String _statusMessage(String? status) => switch (status) {
  'received' => 'El equipo revisará tu solicitud',
  'confirming' => 'Estamos confirmando los datos',
  'validating' => 'La solicitud está siendo validada',
  'assigned' => 'Se asignó un equipo de atención',
  'on_route' => 'El equipo está en camino',
  'on_site' => 'El equipo llegó a la ubicación',
  'in_care' => 'La atención se encuentra en curso',
  'referred' => 'Se coordinó una derivación',
  _ => 'Solicitud activa',
};

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final EmergencyLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: selected ? level.color.withValues(alpha: 0.10) : null,
      border: Border.all(
        color: selected ? level.color : Theme.of(context).colorScheme.outline,
        width: selected ? 1.6 : 1,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: level.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  level.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (selected) Icon(Icons.check_circle_rounded, color: level.color),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.done,
    this.active = false,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.success
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: active ? AppColors.teal : color,
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: TextStyle(
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
