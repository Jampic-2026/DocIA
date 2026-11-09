import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/device_location_service.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/maps_repository.dart';
import '../infrastructure/api/api_maps_repository.dart';

final deviceLocationServiceProvider = Provider<DeviceLocationService>(
  (_) => DeviceLocationService(),
);

final mapsRepositoryProvider = Provider<MapsRepository>(
  (ref) => ApiMapsRepository(ref.watch(authenticatedApiClientProvider)),
);
