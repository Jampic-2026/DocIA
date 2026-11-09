export type CatalogItem = {
  id: string;
  code: string;
  name: string;
  category: string;
  description: string | null;
  chargeMode: string | null;
  coinPrice: number | null;
  price: number | null;
  currency: string | null;
};
