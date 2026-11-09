import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/catalog_item.dart';
import '../../domain/catalog_repository.dart';
class ApiCatalogRepository implements CatalogRepository{
 ApiCatalogRepository(this._client);final AuthenticatedApiClient _client;
 double? _double(Object? value)=>value==null?null:double.tryParse(value.toString());
 int? _int(Object? value)=>value==null?null:int.tryParse(value.toString());
 CatalogServiceAdmin _service(Map<String,dynamic> j)=>CatalogServiceAdmin(
  id:j['id'] as String,code:j['code'] as String,name:j['name'] as String,
  category:j['category'] as String,description:j['description'] as String?,
  isActive:(j['isActive'] as bool?) ?? (j['is_active'] as bool?) ?? true);
 CatalogPriceAdmin _price(Map<String,dynamic> j)=>CatalogPriceAdmin(
  id:j['id'] as String,serviceId:(j['serviceId']??j['service_id']) as String,
  serviceName:(j['serviceName']??j['service_name']) as String? ?? 'Servicio',
  chargeMode:(j['chargeMode']??j['charge_mode']) as String,
  coinPrice:_int(j['coinPrice']??j['coin_price']),
  price:_double(j['price']),
  currency:j['currency'] as String? ?? 'BOB',
  validFrom:(j['validFrom']??j['valid_from'])?.toString(),
  validUntil:(j['validUntil']??j['valid_until'])?.toString());
 @override Future<List<CatalogItem>> list()async{
  final response=await _client.get<Map<String,dynamic>>('catalog/service-catalog');
  final items=response.data?['items'];if(items is! List)throw const FormatException('El catálogo no tiene un formato válido.');
  return items.whereType<Map<String,dynamic>>().map((j)=>CatalogItem(id:j['id'] as String,
   code:j['code'] as String,name:j['name'] as String,category:j['category'] as String,
   description:j['description'] as String?,chargeMode:j['chargeMode'] as String?,
   coinPrice:_int(j['coinPrice']),price:_double(j['price']),
   currency:j['currency'] as String?)).toList();
 }
 @override Future<CatalogManagement> management()async{
  final response=await _client.get<Map<String,dynamic>>('catalog/management');final data=response.data!;
  final services=data['services'] as List? ?? const[];final prices=data['prices'] as List? ?? const[];
  return CatalogManagement(
   services:services.whereType<Map<String,dynamic>>().map(_service).toList(),
   prices:prices.whereType<Map<String,dynamic>>().map(_price).toList());
 }
 @override Future<void> createService({required String code,required String name,required String category,String? description,required bool isActive})async{
  await _client.post<Map<String,dynamic>>('catalog/service-catalog',data:{'code':code,'name':name,'category':category,'description':description,'isActive':isActive});
 }
 @override Future<void> updateService({required String id,required String code,required String name,required String category,String? description,required bool isActive})async{
  await _client.patch<Map<String,dynamic>>('catalog/service-catalog/$id',data:{'code':code,'name':name,'category':category,'description':description,'isActive':isActive});
 }
 @override Future<void> createPrice({required String serviceId,required String chargeMode,int? coinPrice,double? price,required String currency})async{
  await _client.post<Map<String,dynamic>>('catalog/price-list',data:{'serviceId':serviceId,'chargeMode':chargeMode,'coinPrice':coinPrice,'price':price,'currency':currency});
 }
}
