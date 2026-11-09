import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/telemedicine_repository.dart';
import '../domain/telemedicine_room.dart';
import '../domain/telemedicine_activity.dart';
import '../infrastructure/api/api_telemedicine_repository.dart';

final telemedicineRepositoryProvider = Provider<TelemedicineRepository>(
  (ref) => ApiTelemedicineRepository(ref.watch(authenticatedApiClientProvider)),
);

final telemedicineRoomsProvider = FutureProvider<List<TelemedicineRoom>>(
  (ref) => ref.watch(telemedicineRepositoryProvider).listRooms(),
);
final telemedicineActivityProvider =
    FutureProvider.family<TelemedicineActivity, String>(
      (ref, roomId) =>
          ref.watch(telemedicineRepositoryProvider).activity(roomId),
    );
