import type { Market } from './types';

export const mockMarkets: Market[] = [
  {
    id: '0xca048d69BaA38C6364d3E107c2b389BB8D1320dB',
    question: 'Will Bitcoin close above $100k this quarter?',
    description: 'This market resolves to YES if Bitcoin (BTC) closes at or above $100,000.00 USD according to the Binance spot price at any point before the deadline. Otherwise, it resolves to NO.',
    category: 'Crypto',
    image: 'https://images.unsplash.com/photo-1516245834210-c4c142787335?auto=format&fit=crop&w=120&h=120&q=80',
    yesPrice: 0.62,
    noPrice: 0.38,
    totalVolume: 124500,
    deadline: Math.floor(Date.now() / 1000) + 30 * 24 * 3600, // 30 days
    resolved: false,
    outcome: null,
    isContract: true,
  },
  {
    id: 'mock-trump-cabinet',
    question: 'Will Donald Trump announce a new cabinet appointment this week?',
    description: 'Resolves to YES if a new cabinet-level official is formally announced by Donald Trump before Sunday night. Resolves to NO otherwise.',
    category: 'Politics',
    image: 'https://images.unsplash.com/photo-1540910419892-4a36d2c3266c?auto=format&fit=crop&w=120&h=120&q=80',
    yesPrice: 0.74,
    noPrice: 0.26,
    totalVolume: 84920,
    deadline: Math.floor(Date.now() / 1000) + 5 * 24 * 3600,
    resolved: false,
    outcome: null,
  },
  {
    id: 'mock-eth-btc',
    question: 'Will Ethereum outperform Bitcoin in May 2026?',
    description: 'This market resolves to YES if Ethereum (ETH) percentage gain exceeds Bitcoin (BTC) percentage gain between May 1 and May 31, 2026.',
    category: 'Crypto',
    image: 'https://images.unsplash.com/photo-1622790694511-9a5abf68db44?auto=format&fit=crop&w=120&h=120&q=80',
    yesPrice: 0.45,
    noPrice: 0.55,
    totalVolume: 51200,
    deadline: Math.floor(Date.now() / 1000) + 12 * 24 * 3600,
    resolved: false,
    outcome: null,
  },
  {
    id: 'mock-starship',
    question: 'Will SpaceX successfully launch Starship Flight 6?',
    description: 'Resolves to YES if SpaceX launches Starship Flight 6 and successfully completes the hot-stage separation and booster splashdown. Resolves to NO if launch is delayed or fails.',
    category: 'Science',
    image: 'https://images.unsplash.com/photo-1541185933-ef5d8ed016c2?auto=format&fit=crop&w=120&h=120&q=80',
    yesPrice: 0.89,
    noPrice: 0.11,
    totalVolume: 320500,
    deadline: Math.floor(Date.now() / 1000) + 15 * 24 * 3600,
    resolved: false,
    outcome: null,
  },
  {
    id: 'mock-gpt5',
    question: 'Will OpenAI release GPT-5 before July 1, 2026?',
    description: 'This market resolves to YES if OpenAI formally announces and releases a successor model named GPT-5 or a model explicitly designated as its next-generation frontier model before July 1, 2026.',
    category: 'Science',
    image: 'https://images.unsplash.com/photo-1677442136019-21780efad99a?auto=format&fit=crop&w=120&h=120&q=80',
    yesPrice: 0.35,
    noPrice: 0.65,
    totalVolume: 412900,
    deadline: Math.floor(Date.now() / 1000) + 40 * 24 * 3600,
    resolved: false,
    outcome: null,
  },
  {
    id: 'mock-nba-celtics',
    question: 'Will the Boston Celtics win the 2026 NBA Finals?',
    description: 'Resolves to YES if the Boston Celtics win the 2026 NBA Championship Finals. Resolves to NO if any other team wins.',
    category: 'Sports',
    image: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=120&h=120&q=80',
    yesPrice: 0.58,
    noPrice: 0.42,
    totalVolume: 231000,
    deadline: Math.floor(Date.now() / 1000) + 20 * 24 * 3600,
    resolved: false,
    outcome: null,
  },
  {
    id: 'mock-taylor-swift',
    question: 'Will Taylor Swift release a new studio album in 2026?',
    description: 'Resolves to YES if Taylor Swift releases a brand new studio album (excluding re-recordings or live albums) between January 1, 2026, and December 31, 2026.',
    category: 'Pop Culture',
    image: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=120&h=120&q=80',
    yesPrice: 0.28,
    noPrice: 0.72,
    totalVolume: 153400,
    deadline: Math.floor(Date.now() / 1000) + 60 * 24 * 3600,
    resolved: false,
    outcome: null,
  },
  {
    id: 'mock-fed-rates',
    question: 'Will the Federal Reserve lower interest rates in their next meeting?',
    description: 'This market resolves to YES if the Federal Open Market Committee (FOMC) announces a decrease in the federal funds target rate at their next official meeting. Resolves to NO otherwise.',
    category: 'Politics',
    image: 'https://images.unsplash.com/photo-1526304640581-d334cdbbf45e?auto=format&fit=crop&w=120&h=120&q=80',
    yesPrice: 0.52,
    noPrice: 0.48,
    totalVolume: 92800,
    deadline: Math.floor(Date.now() / 1000) + 25 * 24 * 3600,
    resolved: false,
    outcome: null,
  }
];

export const generateMockChartData = (basePrice: number, pointsCount = 30) => {
  const data = [];
  let currentPrice = basePrice * 100; // work in integers / cents
  const now = Date.now();
  const timeStep = 24 * 3600 * 1000; // 1 day steps
  
  for (let i = pointsCount - 1; i >= 0; i--) {
    const time = now - i * timeStep;
    // Add random walk with mean-reversion tendencies
    const change = (Math.random() - 0.48) * 6; // slightly positive drift
    currentPrice = Math.max(10, Math.min(90, currentPrice + change));
    data.push({
      time: new Date(time).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      price: Math.round(currentPrice) / 100
    });
  }
  
  return data;
};
