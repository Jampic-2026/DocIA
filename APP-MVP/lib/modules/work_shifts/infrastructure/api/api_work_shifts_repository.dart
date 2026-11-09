import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/work_shifts_repository.dart';

class ApiWorkShiftsRepository implements WorkShiftsRepository {
  ApiWorkShiftsRepository(this.client);
  final AuthenticatedApiClient client;
  @override
  Future<List<WorkShift>> list({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await client.get<Map<String, dynamic>>(
      'professionals/work-shifts',
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    return (response.data!['items'] as List)
        .map(
          (item) => WorkShift(
            id: item['id'] as String,
            professionalId: item['professionalId'] as String,
            professionalName: item['professionalName'] as String,
            startAt: DateTime.parse(item['startAt'] as String).toLocal(),
            endAt: DateTime.parse(item['endAt'] as String).toLocal(),
            status: item['status'] as String,
            location: item['location'] as String? ?? 'Sede no registrada',
            area: item['area'] as String?,
            notes: item['notes'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<List<StaffAvailability>> availableStaff(StaffFilter filter) async {
    final response = await client.get<Map<String, dynamic>>(
      'professionals/available-staff',
      queryParameters: {
        if (filter.role != null) 'role': filter.role,
        if (filter.location != null) 'location': filter.location,
        if (filter.specialtyId != null) 'specialtyId': filter.specialtyId,
        'availableOnly': filter.availableOnly.toString(),
        if (filter.serviceType != null) 'serviceType': filter.serviceType,
      },
    );
    return (response.data!['items'] as List)
        .map(
          (item) => StaffAvailability(
            id: item['id'] as String,
            name: item['name'] as String,
            role: item['role'] as String,
            availableNow: item['availableNow'] as bool,
            location: item['location'] as String?,
            area: item['area'] as String?,
            specialty: item['specialty'] as String?,
            specialtyId: item['specialtyId'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<void> save({
    String? id,
    required String professionalId,
    required DateTime startAt,
    required DateTime endAt,
    required String location,
    String? area,
    String? notes,
    required String status,
    required String reason,
  }) async {
    final data = {
      'professionalId': professionalId,
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
      'location': location,
      'area': area,
      'notes': notes,
      'status': status,
      'reason': reason,
    };
    if (id == null) {
      await client.post<Map<String, dynamic>>(
        'professionals/work-shifts',
        data: data,
      );
    } else {
      await client.patch<Map<String, dynamic>>(
        'professionals/work-shifts/$id',
        data: data,
      );
    }
  }
}
