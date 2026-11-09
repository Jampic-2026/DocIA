class PartnerSummary{
 const PartnerSummary({required this.id,required this.name,required this.partnerType,
  required this.isActive,required this.siteCount,this.taxId,this.phone,this.email,this.address,
  this.subscriptionStatus,this.planName});
 final String id,name,partnerType; final bool isActive; final int siteCount;
 final String? taxId,phone,email,address,subscriptionStatus,planName;
}
