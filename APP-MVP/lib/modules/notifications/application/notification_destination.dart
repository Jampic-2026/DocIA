import '../../../core/authorization/route_access_policy.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/user_role.dart';
import '../domain/app_notification.dart';

/// Only internal, known destinations; notification payloads cannot supply URLs.
String? notificationDestination(AppNotification item, AppUser user) {
  final patient = user.experience == UserExperience.patient;
  final professional = user.experience == UserExperience.professional;
  final admin = user.experience == UserExperience.administration;
  final operations = user.experience == UserExperience.operations;
  final type = item.relatedEntityType ?? '';
  final category = item.eventCode.split('.').first;
  String? path;
  final query = <String, String>{};
  if (type == 'support_call_request') {
    if (patient || professional) {
      path = patient ? '/patient/support-calls' : '/doctor/support-calls';
      if (item.relatedEntityId != null) query['callId'] = item.relatedEntityId!;
    } else if (admin || operations) {
      if (!user.can('emergencies.manage')) return null;
      if (!user.roles.any(
        (role) => {'admin', 'operator', 'clinical_supervisor'}.contains(role),
      )) {
        return null;
      }
      path = admin ? '/admin/management' : '/operations';
      query['tab'] = 'support_calls';
    }
  } else if (category == 'telemedicine' || type == 'telemedicine_room') {
    path = patient
        ? '/patient/telemedicine'
        : professional
        ? '/doctor/teleconsult'
        : null;
  } else if (type == 'appointment_followup') {
    path = patient
        ? '/patient/appointments'
        : professional
        ? '/doctor/agenda'
        : null;
  } else if (type == 'work_shift') {
    path = professional
        ? '/doctor/agenda/availability'
        : admin
        ? '/admin/management'
        : null;
    if (admin) query['tab'] = 'work_shifts';
  } else if (category == 'appointments' ||
      category == 'appointment' ||
      type == 'appointment' ||
      type == 'referral') {
    if (patient) {
      path = '/patient/appointments';
      if (type == 'appointment' && item.relatedEntityId != null) {
        path = '/patient/appointments/appointment-detail';
        query['id'] = item.relatedEntityId!;
      }
    } else if (professional) {
      path = '/doctor/agenda';
    }
  } else if (category == 'emergencies' ||
      category == 'emergency' ||
      type == 'emergency_event') {
    path = patient
        ? '/patient/emergency'
        : professional
        ? '/doctor/emergency-cases'
        : admin
        ? '/admin/management'
        : operations
        ? '/operations'
        : null;
    if (admin || operations) query['tab'] = 'emergencies';
  } else if (category == 'prescriptions' ||
      category == 'prescription' ||
      type == 'prescription') {
    path = patient
        ? '/patient/prescriptions'
        : professional
        ? '/doctor/prescription'
        : null;
  } else if (category == 'incidents' ||
      category == 'incident' ||
      type == 'incident') {
    path = '/incidents';
  } else if (category == 'payments' ||
      category == 'payment' ||
      type == 'payment_order' ||
      type == 'payment') {
    path = admin ? '/admin/management' : '/payments';
    if (admin) query['tab'] = 'payments';
  } else if (category == 'promotions' || type == 'benefit') {
    path = '/benefits';
  } else if (category == 'coins' || type == 'coin_wallet') {
    path = patient
        ? '/patient/coins'
        : professional
        ? '/doctor/profile/coins'
        : admin
        ? '/admin/management'
        : '/operations/profile/coins';
    if (admin) query['tab'] = 'coins';
  } else if (type == 'diagnostic_order' ||
      type == 'diagnostic_result' ||
      category == 'clinical_records') {
    path = patient
        ? '/patient/clinical-profile'
        : professional
        ? '/doctor/patients'
        : null;
  } else if (type == 'professional' || type == 'personnel_application') {
    path = professional
        ? '/doctor/profile/professional-profile'
        : patient
        ? '/patient/profile/professional-application'
        : admin
        ? '/admin/management'
        : null;
    if (admin) {
      query['tab'] = type == 'professional' ? 'professionals' : 'applications';
    }
  }
  if (path == null || user.experience == UserExperience.unsupported) {
    return null;
  }
  final required = RouteAccessPolicy.requiredAnyPermission(path);
  if (required != null && !required.any(user.can)) return null;
  final tabPermission = <String, String>{
    'support_calls': 'emergencies.manage',
    'emergencies': 'emergencies.read',
    'payments': 'payments.manage',
    'coins': 'coins.manage',
    'professionals': 'professionals.read',
    'applications': 'human_resources.read',
    'work_shifts': 'human_resources.read',
  }[query['tab']];
  if (tabPermission != null && !user.can(tabPermission)) return null;
  return Uri(
    path: path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}
