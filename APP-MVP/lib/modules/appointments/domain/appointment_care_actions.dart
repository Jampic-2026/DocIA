class AppointmentCareActions {
  const AppointmentCareActions({required this.followups,required this.referrals,required this.ratings});
  final List<AppointmentFollowup> followups;final List<MedicalReferral> referrals;final List<AppointmentRating> ratings;
}
class AppointmentFollowup {const AppointmentFollowup({required this.id,required this.sourceAppointmentId,required this.professionalName,required this.status,this.dueAt,this.instructions});
  final String id,sourceAppointmentId,professionalName,status;final DateTime? dueAt;final String? instructions;}
class MedicalReferral {const MedicalReferral({required this.id,required this.specialty,required this.reason,required this.priority,required this.referralType,required this.status,required this.professionalName,this.validUntil});
  final String id,specialty,reason,priority,referralType,status,professionalName;final DateTime? validUntil;}
class AppointmentRating {const AppointmentRating({required this.id,required this.appointmentId,required this.rating,this.comment});
  final String id,appointmentId;final int rating;final String? comment;}
