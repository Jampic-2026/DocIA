import 'catalog_item.dart';

class CatalogManagement {
  const CatalogManagement({required this.services, required this.prices});
  final List<CatalogServiceAdmin> services;
  final List<CatalogPriceAdmin> prices;
}

class CatalogServiceAdmin {
  const CatalogServiceAdmin({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.isActive,
    this.description,
  });
  final String id, code, name, category;
  final String? description;
  final bool isActive;
}

class CatalogPriceAdmin {
  const CatalogPriceAdmin({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.chargeMode,
    required this.currency,
    this.coinPrice,
    this.price,
    this.validFrom,
    this.validUntil,
  });
  final String id, serviceId, serviceName, chargeMode, currency;
  final int? coinPrice;
  final double? price;
  final String? validFrom, validUntil;
}

abstract interface class CatalogRepository {
  Future<List<CatalogItem>> list();
  Future<CatalogManagement> management();
  Future<void> createService({
    required String code,
    required String name,
    required String category,
    String? description,
    required bool isActive,
  });
  Future<void> updateService({
    required String id,
    required String code,
    required String name,
    required String category,
    String? description,
    required bool isActive,
  });
  Future<void> createPrice({
    required String serviceId,
    required String chargeMode,
    int? coinPrice,
    double? price,
    required String currency,
  });
}
