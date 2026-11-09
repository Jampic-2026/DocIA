import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client_provider.dart';
import '../domain/catalog_item.dart';
import '../domain/catalog_repository.dart';
import '../infrastructure/api/api_catalog_repository.dart';
final catalogRepositoryProvider=Provider<CatalogRepository>(
 (ref)=>ApiCatalogRepository(ref.watch(authenticatedApiClientProvider)));
final catalogProvider=FutureProvider<List<CatalogItem>>((ref)=>ref.watch(catalogRepositoryProvider).list());
final catalogManagementProvider=FutureProvider<CatalogManagement>((ref)=>ref.watch(catalogRepositoryProvider).management());
