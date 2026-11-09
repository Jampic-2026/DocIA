import 'location_preview.dart';

abstract interface class MapsRepository {
  Future<LocationPreview> preview({
    required double latitude,
    required double longitude,
  });
}
