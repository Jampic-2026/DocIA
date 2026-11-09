import 'dart:typed_data';

class LocationPreview {
  const LocationPreview({
    required this.latitude,
    required this.longitude,
    this.imageBytes,
    this.address,
  });

  final double latitude;
  final double longitude;
  final Uint8List? imageBytes;
  final String? address;
}
