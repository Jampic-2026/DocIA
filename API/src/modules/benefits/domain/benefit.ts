export type Benefit = {
  id: string;
  code: string;
  name: string;
  description: string | null;
  discountPercent: string | null;
  discountAmount: string | null;
  discountCoinAmount: string | null;
  benefitType: string;
  maxUsesPerUser: number | null;
  isStackable: boolean;
  validFrom: Date | null;
  validUntil: Date | null;
  conditions: Record<string, unknown>;
  usedCount: number;
  available: boolean;
  partnerNames: string[];
};

export type BenefitUsage = {
  id: string;
  benefitName: string;
  discountApplied: string;
  coinDiscountApplied: string;
  status: string;
  usedAt: Date;
};
