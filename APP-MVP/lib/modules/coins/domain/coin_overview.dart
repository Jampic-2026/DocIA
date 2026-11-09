class CoinOverview{
 const CoinOverview({required this.availableBalance,required this.reservedBalance,required this.transactions,required this.packages});
 final int availableBalance,reservedBalance;final List<CoinTransaction> transactions;final List<CoinPackage> packages;
}
class CoinTransaction{const CoinTransaction({required this.id,required this.type,required this.amount,required this.balanceAfter,required this.createdAt,this.reason});
final String id,type;final int amount,balanceAfter;final DateTime createdAt;final String? reason;}
class CoinPackage{const CoinPackage({required this.id,required this.name,required this.coinAmount,required this.bonusCoinAmount,required this.price,required this.currency,this.code,this.description,this.qrImageUrl,this.isActive=true});
final String id,name,currency;final String? code;final int coinAmount,bonusCoinAmount;final double price;final String? description,qrImageUrl;final bool isActive;}
class CoinPurchaseOrder{const CoinPurchaseOrder({required this.id,required this.paymentOrderId,required this.amount,required this.currency,required this.status});
final String id,paymentOrderId,currency,status;final double amount;
factory CoinPurchaseOrder.fromJson(Map<String,dynamic> json)=>CoinPurchaseOrder(
 id:json['id'] as String,paymentOrderId:json['paymentOrderId'] as String,
 amount:double.parse(json['amount'].toString()),currency:json['currency'] as String,status:json['status'] as String);}
