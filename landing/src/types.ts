export interface Market {
  id: string;
  question: string;
  description: string;
  category: string;
  image: string;
  yesPrice: number;
  noPrice: number;
  totalVolume: number;
  deadline: number;
  resolved: boolean;
  outcome: boolean | null;
  isContract?: boolean;
}

export interface Position {
  id: string;
  marketId: string;
  question: string;
  side: 'YES' | 'NO';
  usdcAmount: number;
  entryPrice: number;
  state: string;
  txHash: string | null;
  timestamp: string;
}

export interface WalletInfo {
  walletId: string;
  address: string;
  usdcBalance: string;
  network?: string;
  chainId?: number;
  rpc?: string;
  explorer?: string;
}
