class CatalogItem{
 const CatalogItem({required this.id,required this.code,required this.name,required this.category,
  this.description,this.chargeMode,this.coinPrice,this.price,this.currency});
 final String id,code,name,category;final String? description,chargeMode,currency;
 final int? coinPrice;final double? price;
}
