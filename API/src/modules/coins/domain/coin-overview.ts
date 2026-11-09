export type CoinOverview = {
  availableBalance: number;
  reservedBalance: number;
  lifetimeCredited: number;
  lifetimeSpent: number;
  transactions: Array<{
    id: string;
    type: string;
    amount: number;
    balanceAfter: number;
    reason: string | null;
    createdAt: Date;
  }>;
  packages: Array<{
    id: string;
    code?: string;
    name: string;
    description: string | null;
    coinAmount: number;
    bonusCoinAmount: number;
    price: number;
    currency: string;
    qrImageUrl: string | null;
    isActive?: boolean;
  }>;
};
