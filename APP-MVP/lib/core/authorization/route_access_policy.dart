import 'permission_codes.dart';

abstract final class RouteAccessPolicy {
  static Set<String>? requiredAnyPermission(String location) {
    final permission = requiredPermission(location);
    if (permission != null) return {permission};

    if (location.startsWith('/admin/management')) {
      return {
        PermissionCodes.administrationManage,
        PermissionCodes.administrationRead,
        PermissionCodes.humanResourcesRead,
        PermissionCodes.humanResourcesManage,
        PermissionCodes.aiManage,
        PermissionCodes.emergenciesManage,
        PermissionCodes.partnersRead,
        PermissionCodes.professionalsRead,
        PermissionCodes.emergenciesRead,
        PermissionCodes.clinicalRecordsManage,
        PermissionCodes.auditRead,
        PermissionCodes.usersRead,
        PermissionCodes.catalogManage,
        PermissionCodes.coinsManage,
        PermissionCodes.paymentsManage,
      };
    }
    if (location.startsWith('/admin')) {
      return {
        PermissionCodes.administrationRead,
        PermissionCodes.humanResourcesRead,
        PermissionCodes.partnersRead,
      };
    }
    if (location.startsWith('/operations')) {
      return {
        PermissionCodes.aiManage,
        PermissionCodes.emergenciesRead,
        PermissionCodes.deliveriesRead,
        PermissionCodes.incidentsRead,
        PermissionCodes.notificationsRead,
        PermissionCodes.clinicalRecordsManage,
      };
    }

    return null;
  }

  static String? requiredPermission(String location) {
    if (location == '/notifications' || location == '/patient/notifications') {
      return PermissionCodes.notificationsRead;
    }
    if (location == '/incidents') {
      return PermissionCodes.incidentsRead;
    }
    if (location == '/benefits') {
      return PermissionCodes.benefitsRead;
    }
    if (location == '/payments') {
      return PermissionCodes.paymentsRead;
    }
    if (location.startsWith('/patient/appointments')) {
      return PermissionCodes.appointmentsRead;
    }
    if (location.startsWith('/patient/support-calls')) {
      return PermissionCodes.appointmentsRead;
    }
    if (location.startsWith('/doctor/emergency-cases')) {
      return PermissionCodes.emergenciesRead;
    }
    if (location.startsWith('/patient/assistant')) {
      return PermissionCodes.aiUse;
    }
    if (location.startsWith('/patient/clinical-profile') ||
        location.startsWith('/patient/medical-history') ||
        location.startsWith('/patient/vital-signs') ||
        location.startsWith('/patient/clinical-documents') ||
        location.startsWith('/patient/clinical-corrections')) {
      return PermissionCodes.clinicalRecordsRead;
    }
    if (location.startsWith('/patient/family')) {
      return PermissionCodes.patientsRead;
    }
    if (location.startsWith('/patient/emergency')) {
      return PermissionCodes.emergenciesRead;
    }
    if (location.startsWith('/patient/directory')) {
      return PermissionCodes.professionalsRead;
    }
    if (location.startsWith('/patient/telemedicine')) {
      return PermissionCodes.appointmentsRead;
    }
    if (location.startsWith('/patient/prescriptions')) {
      return PermissionCodes.prescriptionsRead;
    }
    if (location.startsWith('/patient/catalog') ||
        location.startsWith('/patient/profile/catalog')) {
      return PermissionCodes.catalogRead;
    }
    if (location.startsWith('/patient/coins') ||
        location.startsWith('/patient/profile/coins')) {
      return PermissionCodes.coinsRead;
    }
    if (location.startsWith('/patient/profile/consents')) {
      return PermissionCodes.consentsRead;
    }
    if (location.startsWith('/patient/profile/incidents')) {
      return PermissionCodes.incidentsRead;
    }
    if (location.startsWith('/patient/profile/benefits')) {
      return PermissionCodes.benefitsRead;
    }
    if (location.startsWith('/patient/profile/payments')) {
      return PermissionCodes.paymentsRead;
    }
    if (location == '/patient') {
      return PermissionCodes.patientsRead;
    }

    if (location.startsWith('/doctor/clinical-note')) {
      return PermissionCodes.clinicalRecordsManage;
    }
    if (location.startsWith('/doctor/patients/patient-record')) {
      return PermissionCodes.clinicalRecordsRead;
    }
    if (location.startsWith('/doctor/prescription')) {
      return PermissionCodes.prescriptionsManage;
    }
    if (location.startsWith('/doctor/profile/professional-profile') ||
        location.startsWith('/doctor/agenda/availability')) {
      return PermissionCodes.professionalsRead;
    }
    if (location.startsWith('/doctor/profile/consents')) {
      return PermissionCodes.consentsRead;
    }
    if (location.startsWith('/doctor/profile/incidents')) {
      return PermissionCodes.incidentsRead;
    }
    if (location.startsWith('/doctor/profile/catalog')) {
      return PermissionCodes.catalogRead;
    }
    if (location.startsWith('/doctor/profile/coins')) {
      return PermissionCodes.coinsRead;
    }
    if (location.startsWith('/doctor/profile/benefits')) {
      return PermissionCodes.benefitsRead;
    }
    if (location.startsWith('/doctor/profile/payments')) {
      return PermissionCodes.paymentsRead;
    }
    if (location.startsWith('/doctor/profile/help')) {
      return null;
    }
    if (location.startsWith('/doctor')) {
      return PermissionCodes.appointmentsRead;
    }

    if (location.startsWith('/operations/profile/consents')) {
      return PermissionCodes.consentsRead;
    }
    if (location.startsWith('/operations/profile/incidents')) {
      return PermissionCodes.incidentsRead;
    }
    if (location.startsWith('/operations/profile/catalog')) {
      return PermissionCodes.catalogRead;
    }
    if (location.startsWith('/operations/profile/coins')) {
      return PermissionCodes.coinsRead;
    }
    if (location.startsWith('/operations/profile/benefits')) {
      return PermissionCodes.benefitsRead;
    }
    if (location.startsWith('/operations/profile/payments')) {
      return PermissionCodes.paymentsRead;
    }
    if (location.startsWith('/operations/profile/help')) {
      return null;
    }

    return null;
  }
}
