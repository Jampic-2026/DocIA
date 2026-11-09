import '../../../../core/network/authenticated_api_client.dart';
import '../../domain/coin_overview.dart';
import '../../domain/coins_repository.dart';
class ApiCoinsRepository implements CoinsRepository{
 ApiCoinsRepository(this._client);final AuthenticatedApiClient _client;
 int _int(Object? value)=>int.tryParse(value.toString()) ?? 0;
 double _double(Object? value)=>double.tryParse(value.toString()) ?? 0;
 @override Future<CoinOverview> overview()async{
  final response=await _client.get<Map<String,dynamic>>('coins/overview');final j=response.data!;
  final tx=j['transactions'] as List? ?? const[];final packs=j['packages'] as List? ?? const[];
  return CoinOverview(availableBalance:_int(j['availableBalance']),
   reservedBalance:_int(j['reservedBalance']),
   transactions:tx.whereType<Map<String,dynamic>>().map((t)=>CoinTransaction(id:t['id'] as String,
    type:t['type'] as String,amount:_int(t['amount']),balanceAfter:_int(t['balanceAfter']),
    reason:t['reason'] as String?,createdAt:DateTime.parse(t['createdAt'] as String).toLocal())).toList(),
   packages:packs.whereType<Map<String,dynamic>>().map((p)=>CoinPackage(id:p['id'] as String,
    code:p['code'] as String?,name:p['name'] as String,description:p['description'] as String?,coinAmount:_int(p['coinAmount']),
    bonusCoinAmount:_int(p['bonusCoinAmount']),price:_double(p['price']),
    currency:p['currency'] as String,qrImageUrl:p['qrImageUrl'] as String?,isActive:(p['isActive'] as bool?) ?? true)).toList());
 }
 @override Future<CoinPurchaseOrder> purchase(String packageId)async{
  final response=await _client.post<Map<String,dynamic>>('coins/purchases',data:{'packageId':packageId});
  return CoinPurchaseOrder.fromJson(response.data!);
 }
 @override Future<void> createPackage({required String code,required String name,String? description,String? qrImageUrl,required int coinAmount,required int bonusCoinAmount,required double price,required String currency,required bool isActive})async{
  await _client.post<Map<String,dynamic>>('coins/coin-packages',data:{'code':code,'name':name,'description':description,'qrImageUrl':qrImageUrl,'coinAmount':coinAmount,'bonusCoinAmount':bonusCoinAmount,'price':price,'currency':currency,'isActive':isActive});
 }
 @override Future<void> updatePackage({required String id,required String code,required String name,String? description,String? qrImageUrl,required int coinAmount,required int bonusCoinAmount,required double price,required String currency,required bool isActive})async{
  await _client.patch<Map<String,dynamic>>('coins/coin-packages/$id',data:{'code':code,'name':name,'description':description,'qrImageUrl':qrImageUrl,'coinAmount':coinAmount,'bonusCoinAmount':bonusCoinAmount,'price':price,'currency':currency,'isActive':isActive});
 }
 @override Future<void> deletePackage(String id)async{
  await _client.delete<Map<String,dynamic>>('coins/coin-packages/$id');
 }
}
