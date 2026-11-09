import 'coin_overview.dart';
abstract interface class CoinsRepository{
 Future<CoinOverview> overview();
 Future<CoinPurchaseOrder> purchase(String packageId);
 Future<void> createPackage({required String code,required String name,String? description,String? qrImageUrl,required int coinAmount,required int bonusCoinAmount,required double price,required String currency,required bool isActive});
 Future<void> updatePackage({required String id,required String code,required String name,String? description,String? qrImageUrl,required int coinAmount,required int bonusCoinAmount,required double price,required String currency,required bool isActive});
 Future<void> deletePackage(String id);
}
