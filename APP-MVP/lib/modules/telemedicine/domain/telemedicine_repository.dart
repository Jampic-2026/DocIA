import 'telemedicine_room.dart';
import 'telemedicine_activity.dart';

abstract interface class TelemedicineRepository {
  Future<List<TelemedicineRoom>> listRooms();
  Future<void> createRoom(String appointmentId);
  Future<void> registerJoin(String roomId);
  Future<void> registerLeave(String roomId);
  Future<void> closeRoom(String roomId);
  Future<void> registerConnectionFailure(String roomId);
  Future<TelemedicineActivity> activity(String roomId);
  Future<void> shareFile(String roomId, String clinicalDocumentId);
}
