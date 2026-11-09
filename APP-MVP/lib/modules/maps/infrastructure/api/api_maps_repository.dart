import 'dart:convert';

import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/location_preview.dart';
import '../../domain/maps_repository.dart';

class ApiMapsRepository implements MapsRepository {
  ApiMapsRepository(this._client);
  final AuthenticatedApiClient _client;

  @override
  Future<LocationPreview> preview({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      'maps/location-preview',
      data: {'latitude': latitude, 'longitude': longitude},
    );
    final json = response.data!;
    final encodedImage = json['imageBase64'] as String?;
    return LocationPreview(
      latitude: latitude,
      longitude: longitude,
      address: json['address'] as String?,
      imageBytes: encodedImage == null || encodedImage.isEmpty
          ? null
          : base64Decode(encodedImage),
    );
  }
}
