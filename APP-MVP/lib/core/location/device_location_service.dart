import 'package:geolocator/geolocator.dart';

import 'device_location.dart';

class DeviceLocationService {
  Future<DeviceLocation> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Activa la ubicación del dispositivo para continuar.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'No se otorgó permiso de ubicación. Puedes ingresar la dirección manualmente.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'El permiso de ubicación está bloqueado. Habilítalo en la configuración o ingresa la dirección.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );
  }
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}
