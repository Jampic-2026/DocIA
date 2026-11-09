export type PartnerSummary = {
  id: string;
  name: string;
  partnerType: string;
  taxId: string | null;
  phone: string | null;
  email: string | null;
  address: string | null;
  isActive: boolean;
  subscriptionStatus: string | null;
  planName: string | null;
  siteCount: number;
};
