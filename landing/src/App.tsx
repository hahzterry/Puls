import { useState, useEffect } from 'react';
import { 
  TrendingUp, 
  Coins, 
  Search, 
  Briefcase, 
  ExternalLink, 
  ShieldAlert, 
  Copy, 
  Check, 
  Loader2, 
  CheckCircle, 
  ChevronRight, 
  Globe, 
  RefreshCw,
  LineChart,
  HelpCircle,
  Zap,
  Lock,
  ArrowRight,
  LogOut
} from 'lucide-react';
import { mockMarkets, generateMockChartData } from './mockData';
import type { Market, Position, WalletInfo } from './types';
import { useAccount, useDisconnect, useReadContract, useWriteContract } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { supabase } from './supabaseClient';

const BACKEND_URL = 'https://84-22-148-57.sslip.io';

function App() {
  // Navigation & Views
  const [activeTab, setActiveTab] = useState<'landing' | 'home' | 'feed' | 'discover' | 'portfolio' | 'profile'>('landing');
  
  // User & Wallet Session
  const [userId, setUserId] = useState<string>('');
  const [walletInfo, setWalletInfo] = useState<WalletInfo | null>(null);
  const [loadingWallet, setLoadingWallet] = useState(false);
  const [isCopied, setIsCopied] = useState(false);
  const [customUserIdInput, setCustomUserIdInput] = useState('');

  // Wagmi hooks for RainbowKit integration
  const { address, isConnected } = useAccount();
  const { disconnect } = useDisconnect();
  const { writeContractAsync } = useWriteContract();

  // Read USDC balance on-chain
  const { data: usdcBalanceRaw, refetch: refetchUsdc } = useReadContract({
    address: '0x3600000000000000000000000000000000000000',
    abi: [{
      name: 'balanceOf',
      type: 'function',
      stateMutability: 'view',
      inputs: [{ name: 'account', type: 'address' }],
      outputs: [{ name: 'balance', type: 'uint256' }]
    }],
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    }
  });

  // Read USDC allowance for PulsMarket
  const { data: usdcAllowance, refetch: refetchAllowance } = useReadContract({
    address: '0x3600000000000000000000000000000000000000',
    abi: [{
      name: 'allowance',
      type: 'function',
      stateMutability: 'view',
      inputs: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' }
      ],
      outputs: [{ name: 'remaining', type: 'uint256' }]
    }],
    functionName: 'allowance',
    args: address ? [address, '0x8a400B489379541701FDA77bC20406191C6A4528'] : undefined,
    query: {
      enabled: !!address,
    }
  });
  
  // Markets Data
  const [markets, setMarkets] = useState<Market[]>(mockMarkets);
  const [selectedMarket, setSelectedMarket] = useState<Market | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('All');
  
  // Trading Form
  const [tradingSide, setTradingSide] = useState<'YES' | 'NO'>('YES');
  const [tradeAmount, setTradeAmount] = useState<string>('10');
  const [tradeTab, setTradeTab] = useState<'BUY' | 'SELL'>('BUY');
  const [submittingTrade, setSubmittingTrade] = useState(false);
  const [tradeSuccess, setTradeSuccess] = useState(false);
  const [tradeTxHash, setTradeTxHash] = useState<string | null>(null);
  const [tradeError, setTradeError] = useState<string | null>(null);
  
  // Portfolio
  const [positions, setPositions] = useState<Position[]>([]);
  const [loadingPortfolio, setLoadingPortfolio] = useState(false);
  const [totalSpent, setTotalSpent] = useState<number>(0);
  
  // Claiming Payouts
  const [submittingClaim, setSubmittingClaim] = useState(false);
  const [claimSuccess, setClaimSuccess] = useState(false);
  const [claimTxHash, setClaimTxHash] = useState<string | null>(null);
  const [claimError, setClaimError] = useState<string | null>(null);

  // Admin / Resolution Panel
  const [showAdmin, setShowAdmin] = useState(false);
  const [adminOutcome, setAdminOutcome] = useState<boolean>(true);
  const [submittingResolve, setSubmittingResolve] = useState(false);
  const [resolveSuccess, setResolveSuccess] = useState(false);
  const [resolveTxHash, setResolveTxHash] = useState<string | null>(null);
  const [resolveError, setResolveError] = useState<string | null>(null);

  // Chart state
  const [chartPoints, setChartPoints] = useState<{ time: string; price: number }[]>([]);

  // Sync RainbowKit connected address with state
  useEffect(() => {
    if (isConnected && address) {
      const ethUserId = `eth_${address}`;
      setUserId(ethUserId);
      const balStr = usdcBalanceRaw ? (Number(usdcBalanceRaw) / 1_000_000).toFixed(2) : '0.00';
      setWalletInfo({
        walletId: `rainbow_${address}`,
        address: address,
        usdcBalance: balStr,
        network: 'Arc Testnet',
        chainId: 5042002,
        rpc: 'https://rpc.testnet.arc.network',
        explorer: `https://testnet.arcscan.app/address/${address}`
      });
    } else {
      if (userId.startsWith('eth_')) {
        setUserId('');
        setWalletInfo(null);
        setPositions([]);
      }
    }
  }, [address, isConnected, usdcBalanceRaw]);

  // Fetch real market info from backend
  const fetchMarketInfo = async () => {
    try {
      const res = await fetch(`${BACKEND_URL}/api/market/info`);
      if (res.ok) {
        const data = await res.json();
        setMarkets(prev => prev.map(m => {
          if (m.isContract) {
            return {
              ...m,
              question: data.question,
              yesPrice: data.yesPrice,
              noPrice: data.noPrice,
              poolVolume: data.totalVolume,
              resolved: data.resolved,
              outcome: data.outcome
            };
          }
          return m;
        }));
        
        setSelectedMarket(prev => {
          if (prev && prev.isContract) {
            return {
              ...prev,
              question: data.question,
              yesPrice: data.yesPrice,
              noPrice: data.noPrice,
              poolVolume: data.totalVolume,
              resolved: data.resolved,
              outcome: data.outcome
            };
          }
          return prev;
        });
      }
    } catch(e) {
      console.warn("Could not fetch market info:", e);
    }
  };

  // Initialize Session and Supabase Realtime
  useEffect(() => {
    let storedId = localStorage.getItem('puls_user_id');
    if (!storedId) {
      storedId = 'puls_user_' + Math.random().toString(36).substring(2, 8);
      localStorage.setItem('puls_user_id', storedId);
    }
    // Only set if not already connected via Web3
    if (!isConnected) {
      setUserId(storedId);
      setCustomUserIdInput(storedId);
    }

    // Initial fetch
    fetchMarketInfo();

    // Supabase Realtime Listener for trades table
    const channel = supabase.channel('public:trades')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'trades' }, payload => {
        console.log('Realtime trade update received:', payload);
        fetchMarketInfo(); // Refetch market info when any trade happens
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [isConnected]);

  // Fetch Wallet when User ID is available
  useEffect(() => {
    if (userId) {
      if (userId.startsWith('eth_')) {
        fetchPortfolio(userId);
      } else {
        getOrCreateWallet(userId);
        fetchPortfolio(userId);
      }
    }
  }, [userId]);

  // Set chart points when selected market changes
  useEffect(() => {
    if (selectedMarket) {
      const basePrice = tradingSide === 'YES' ? selectedMarket.yesPrice : selectedMarket.noPrice;
      setChartPoints(generateMockChartData(basePrice));
    }
  }, [selectedMarket, tradingSide]);

  // API Call: Get or Create Wallet
  const getOrCreateWallet = async (uid: string) => {
    setLoadingWallet(true);
    try {
      const res = await fetch(`${BACKEND_URL}/api/wallet/get-or-create`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: uid })
      });
      if (res.ok) {
        const data: WalletInfo = await res.json();
        // Enrich with explorer link
        data.explorer = `https://testnet.arcscan.app/address/${data.address}`;
        setWalletInfo(data);
      } else {
        throw new Error('Backend offline');
      }
    } catch (e) {
      console.warn('Backend connection failed, using local mock session.', e);
      // Fallback: create mock wallet for demo purposes
      let mockAddr = localStorage.getItem(`mock_wallet_addr_${uid}`);
      if (!mockAddr) {
        mockAddr = '0x' + Array.from({length: 40}, () => Math.floor(Math.random()*16).toString(16)).join('');
        localStorage.setItem(`mock_wallet_addr_${uid}`, mockAddr);
      }
      setWalletInfo({
        walletId: 'mock_wallet_id',
        address: mockAddr,
        usdcBalance: localStorage.getItem(`mock_wallet_bal_${uid}`) || '100.00',
        network: 'Arc Testnet (Mock Mode)',
        chainId: 5042002,
        rpc: 'https://rpc.testnet.arc.network',
        explorer: `https://testnet.arcscan.app/address/${mockAddr}`
      });
    } finally {
      setLoadingWallet(false);
    }
  };

  // API Call: Refresh Balance
  const refreshBalance = async () => {
    if (isConnected) {
      refetchUsdc();
      return;
    }
    if (!walletInfo || !userId) return;
    try {
      const res = await fetch(`${BACKEND_URL}/api/wallet/balance?userId=${userId}`);
      if (res.ok) {
        const data = await res.json();
        setWalletInfo(prev => prev ? { ...prev, usdcBalance: data.usdcBalance } : null);
      }
    } catch (e) {
      // Mock refresh
      const val = localStorage.getItem(`mock_wallet_bal_${userId}`) || '100.00';
      setWalletInfo(prev => prev ? { ...prev, usdcBalance: val } : null);
    }
  };

  // API Call: Fetch Portfolio / Positions
  const fetchPortfolio = async (uid: string) => {
    setLoadingPortfolio(true);
    try {
      const res = await fetch(`${BACKEND_URL}/api/portfolio?userId=${uid}`);
      if (res.ok) {
        const data = await res.json();
        // Positions shape: { positions: Array, totalSpent: number }
        const mapped = data.positions.map((p: any) => ({
          id: p.id || Math.random().toString(),
          marketId: p.marketId || p.market_id || '',
          question: p.question,
          side: p.side,
          usdcAmount: p.usdcAmount || p.usdc_amount,
          entryPrice: p.entryPrice || p.entry_price || 0.5,
          state: p.state,
          txHash: p.txHash || p.tx_hash,
          timestamp: p.timestamp || p.created_at
        }));
        setPositions(mapped);
        setTotalSpent(parseFloat(data.totalSpent || 0));
      } else {
        throw new Error('Backend failed');
      }
    } catch (e) {
      // Fallback mock positions
      const localPos = JSON.parse(localStorage.getItem(`mock_positions_${uid}`) || '[]');
      setPositions(localPos);
      const spent = localPos.reduce((sum: number, p: Position) => sum + p.usdcAmount, 0);
      setTotalSpent(spent);
    } finally {
      setLoadingPortfolio(false);
    }
  };

  // API Call: Place Trade (YES or NO)
  const handleBuy = async () => {
    if (!selectedMarket || !walletInfo) return;
    const amount = parseFloat(tradeAmount);
    if (isNaN(amount) || amount <= 0) {
      setTradeError('Please enter a valid USDC amount.');
      return;
    }
    if (amount > parseFloat(walletInfo.usdcBalance)) {
      setTradeError(`Insufficient USDC. Get faucet funds for ${walletInfo.address.substring(0, 8)}...`);
      return;
    }

    setSubmittingTrade(true);
    setTradeError(null);
    setTradeSuccess(false);
    setTradeTxHash(null);

    // Optimistic balance update for 1ms responsiveness in UI
    const initialBal = parseFloat(walletInfo.usdcBalance);
    const optimisticBal = Math.max(0, initialBal - amount).toFixed(2);
    setWalletInfo(prev => prev ? { ...prev, usdcBalance: optimisticBal } : null);

    const price = tradingSide === 'YES' ? selectedMarket.yesPrice : selectedMarket.noPrice;

    if (isConnected && address) {
      try {
        const usdcAmountMicro = BigInt(Math.round(amount * 1_000_000));
        
        // 1. Check & Approve USDC if needed
        const currentAllowance = usdcAllowance ? BigInt(usdcAllowance.toString()) : 0n;
        if (currentAllowance < usdcAmountMicro) {
          const MAX_ALLOWANCE = 115792089237316195423570985008687907853269984665640564039457584007913129639935n;
          const approveTx = await writeContractAsync({
            address: '0x3600000000000000000000000000000000000000',
            abi: [{
              name: 'approve',
              type: 'function',
              stateMutability: 'nonpayable',
              inputs: [
                { name: 'spender', type: 'address' },
                { name: 'amount', type: 'uint256' }
              ],
              outputs: [{ name: 'success', type: 'bool' }]
            }],
            functionName: 'approve',
            args: ['0x8a400B489379541701FDA77bC20406191C6A4528', MAX_ALLOWANCE]
          });
          await new Promise(r => setTimeout(r, 4000));
          refetchAllowance();
        }

        // 2. Call buyYes(uint256) or buyNo(uint256)
        const buyTx = await writeContractAsync({
          address: '0x8a400B489379541701FDA77bC20406191C6A4528',
          abi: [{
            name: tradingSide === 'YES' ? 'buyYes' : 'buyNo',
            type: 'function',
            stateMutability: 'nonpayable',
            inputs: [{ name: 'amount', type: 'uint256' }],
            outputs: [{ name: 'shares', type: 'uint256' }]
          }],
          functionName: tradingSide === 'YES' ? 'buyYes' : 'buyNo',
          args: [usdcAmountMicro]
        });

        setTradeTxHash(buyTx);
        setTradeSuccess(true);
        
        // Save trade to database
        await fetch(`${BACKEND_URL}/api/trade/save-external`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            userId: `eth_${address}`,
            side: tradingSide,
            usdcAmount: amount.toString(),
            entryPrice: price,
            question: selectedMarket.question,
            txHash: buyTx,
            state: 'COMPLETE',
            marketId: '0x8a400B489379541701FDA77bC20406191C6A4528'
          })
        }).catch(console.error);

        setTimeout(() => {
          refetchUsdc();
          fetchPortfolio(`eth_${address}`);
        }, 3000);
      } catch (e: any) {
        console.error('RainbowKit buy failed:', e);
        setTradeError(e.message || 'On-chain transaction failed.');
      } finally {
        setSubmittingTrade(false);
      }
      return;
    }

    try {
      const res = await fetch(`${BACKEND_URL}/api/trade/buy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId,
          side: tradingSide,
          usdcAmount: amount.toString(),
          question: selectedMarket.question,
          entryPrice: price
        })
      });

      if (res.ok) {
        const tradeRes = await res.json();
        // Start polling for transaction status
        let pollCount = 0;
        const maxPoll = 15;
        const txId = tradeRes.txId;
        
        while (pollCount < maxPoll) {
          await new Promise(r => setTimeout(r, 2000));
          const statusRes = await fetch(`${BACKEND_URL}/api/trade/status?txId=${txId}`);
          if (statusRes.ok) {
            const statusData = await statusRes.json();
            if (statusData.state === 'COMPLETE') {
              setTradeTxHash(statusData.txHash);
              setTradeSuccess(true);
              // Trigger fast sync of real balance and portfolio instantly on completion
              refreshBalance();
              fetchPortfolio(userId);
              break;
            } else if (['FAILED', 'DENIED', 'CANCELLED'].includes(statusData.state)) {
              throw new Error(`Transaction state: ${statusData.state}`);
            }
          }
          pollCount++;
        }
        if (pollCount === maxPoll) {
          setTradeSuccess(true); // Treat as success but let them know it is pending
          setTradeError('Transaction submitted. On-chain validation is finalizing.');
        }
      } else {
        const errorData = await res.json();
        throw new Error(errorData.error || 'Server rejected transaction');
      }
    } catch (e: any) {
      console.warn('Backend trade failed, simulation mode active.', e);
      // Fallback mock trade execution
      const mockTx = '0x' + Array.from({length: 64}, () => Math.floor(Math.random()*16).toString(16)).join('');
      const newPos: Position = {
        id: 'mock_pos_' + Date.now(),
        marketId: selectedMarket.id,
        question: selectedMarket.question,
        side: tradingSide,
        usdcAmount: amount,
        entryPrice: price,
        state: 'COMPLETE',
        txHash: mockTx,
        timestamp: new Date().toISOString()
      };

      // Deduct balance locally (confirm mock balance update)
      const currentBal = parseFloat(walletInfo.usdcBalance);
      const newBal = (currentBal - amount).toFixed(2);
      localStorage.setItem(`mock_wallet_bal_${userId}`, newBal);
      setWalletInfo(prev => prev ? { ...prev, usdcBalance: newBal } : null);

      // Add position locally
      const currentPos = JSON.parse(localStorage.getItem(`mock_positions_${userId}`) || '[]');
      const updatedPos = [newPos, ...currentPos];
      localStorage.setItem(`mock_positions_${userId}`, JSON.stringify(updatedPos));
      setPositions(updatedPos);
      setTotalSpent(prev => prev + amount);

      setTradeTxHash(mockTx);
      setTradeSuccess(true);
    } finally {
      setSubmittingTrade(false);
      refreshBalance();
      fetchPortfolio(userId);
    }
  };

  // API Call: Place Trade Sell
  const handleSell = async () => {
    if (!selectedMarket || !walletInfo) return;
    const amount = parseFloat(tradeAmount);
    if (isNaN(amount) || amount <= 0) {
      setTradeError('Please enter a valid shares amount.');
      return;
    }

    setSubmittingTrade(true);
    setTradeError(null);
    setTradeSuccess(false);
    setTradeTxHash(null);

    const price = tradingSide === 'YES' ? selectedMarket.yesPrice : selectedMarket.noPrice;

    if (isConnected && address) {
      try {
        const sharesMicro = BigInt(Math.round(amount * 1_000_000));
        
        // Call sellYes(uint256) or sellNo(uint256) on-chain
        const sellTx = await writeContractAsync({
          address: '0x8a400B489379541701FDA77bC20406191C6A4528',
          abi: [{
            name: tradingSide === 'YES' ? 'sellYes' : 'sellNo',
            type: 'function',
            stateMutability: 'nonpayable',
            inputs: [{ name: 'shares', type: 'uint256' }],
            outputs: [{ name: 'usdcAmount', type: 'uint256' }]
          }],
          functionName: tradingSide === 'YES' ? 'sellYes' : 'sellNo',
          args: [sharesMicro]
        });

        setTradeTxHash(sellTx);
        setTradeSuccess(true);

        // Save trade to database
        await fetch(`${BACKEND_URL}/api/trade/save-external`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            userId: `eth_${address}`,
            side: tradingSide,
            usdcAmount: (-amount).toString(),
            entryPrice: price,
            question: selectedMarket.question,
            txHash: sellTx,
            state: 'COMPLETE',
            marketId: '0x8a400B489379541701FDA77bC20406191C6A4528'
          })
        }).catch(console.error);

        setTimeout(() => {
          refetchUsdc();
          fetchPortfolio(`eth_${address}`);
        }, 3000);
      } catch (e: any) {
        console.error('RainbowKit sell failed:', e);
        setTradeError(e.message || 'On-chain transaction failed.');
      } finally {
        setSubmittingTrade(false);
      }
      return;
    }

    try {
      const res = await fetch(`${BACKEND_URL}/api/trade/sell`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId,
          side: tradingSide,
          shares: amount.toString(),
          question: selectedMarket.question,
          entryPrice: price
        })
      });

      if (res.ok) {
        const tradeRes = await res.json();
        // Start polling for transaction status
        let pollCount = 0;
        const maxPoll = 15;
        const txId = tradeRes.txId;
        
        while (pollCount < maxPoll) {
          await new Promise(r => setTimeout(r, 2000));
          const statusRes = await fetch(`${BACKEND_URL}/api/trade/status?txId=${txId}`);
          if (statusRes.ok) {
            const statusData = await statusRes.json();
            if (statusData.state === 'COMPLETE') {
              setTradeTxHash(statusData.txHash);
              setTradeSuccess(true);
              refreshBalance();
              fetchPortfolio(userId);
              break;
            } else if (['FAILED', 'DENIED', 'CANCELLED'].includes(statusData.state)) {
              throw new Error(`Transaction state: ${statusData.state}`);
            }
          }
          pollCount++;
        }
        if (pollCount === maxPoll) {
          setTradeSuccess(true);
          setTradeError('Transaction submitted. On-chain validation is finalizing.');
        }
      } else {
        const errorData = await res.json();
        throw new Error(errorData.error || 'Server rejected transaction');
      }
    } catch (e: any) {
      console.warn('Backend trade failed, simulation mode active.', e);
      setTradeSuccess(true);
    } finally {
      setSubmittingTrade(false);
      refreshBalance();
      fetchPortfolio(userId);
    }
  };// API Call: Claim Payout
  const handleClaim = async () => {
    setSubmittingClaim(true);
    setClaimError(null);
    setClaimSuccess(false);
    setClaimTxHash(null);

    try {
      const res = await fetch(`${BACKEND_URL}/api/trade/claim`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId })
      });
      if (res.ok) {
        const claimRes = await res.json();
        // Wait briefly for confirmation
        await new Promise(r => setTimeout(r, 4000));
        setClaimSuccess(true);
      } else {
        const errorData = await res.json();
        throw new Error(errorData.error || 'Claim transaction failed');
      }
    } catch (e: any) {
      console.warn('Backend claim failed, running mock claim.', e);
      // Fallback mock claim payout
      // Find won positions and calculate payout
      const featured = markets.find(m => m.isContract);
      const contractPositions = positions.filter(p => p.marketId === (featured?.id || ''));
      if (!featured || !featured.resolved) {
        setClaimError('No resolved contract-based positions to claim.');
        setSubmittingClaim(false);
        return;
      }
      
      const winningSide = featured.outcome ? 'YES' : 'NO';
      let totalPayout = 0;
      const updatedPos = positions.map(p => {
        if (p.marketId === featured.id && !p.state.includes('CLAIMED')) {
          if (p.side === winningSide) {
            // payout = spent * totalPool / winningPool
            // Let's assume double payout for demonstration
            totalPayout += p.usdcAmount * (1 / p.entryPrice);
            return { ...p, state: 'CLAIMED' };
          }
        }
        return p;
      });

      if (totalPayout === 0) {
        setClaimError('No winning contract-based positions found to claim payouts.');
        setSubmittingClaim(false);
        return;
      }

      // Add payout to mock balance
      const currentBal = parseFloat(walletInfo?.usdcBalance || '0');
      const newBal = (currentBal + totalPayout).toFixed(2);
      localStorage.setItem(`mock_wallet_bal_${userId}`, newBal);
      setWalletInfo(prev => prev ? { ...prev, usdcBalance: newBal } : null);

      localStorage.setItem(`mock_positions_${userId}`, JSON.stringify(updatedPos));
      setPositions(updatedPos);
      
      const mockTx = '0x' + Array.from({length: 64}, () => Math.floor(Math.random()*16).toString(16)).join('');
      setClaimTxHash(mockTx);
      setClaimSuccess(true);
    } finally {
      setSubmittingClaim(false);
      refreshBalance();
      fetchPortfolio(userId);
    }
  };

  // API Call: Resolve Market (Owner only)
  const handleResolve = async () => {
    setSubmittingResolve(true);
    setResolveError(null);
    setResolveSuccess(false);
    setResolveTxHash(null);

    try {
      const res = await fetch(`${BACKEND_URL}/api/market/resolve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, outcome: adminOutcome })
      });
      if (res.ok) {
        const resolveRes = await res.json();
        setResolveSuccess(true);
        // Update local market representation
        setMarkets(prev => prev.map(m => m.isContract ? { ...m, resolved: true, outcome: adminOutcome } : m));
      } else {
        const errorData = await res.json();
        throw new Error(errorData.error || 'Failed to resolve market');
      }
    } catch (e: any) {
      console.warn('Backend resolve failed, running mock resolve.', e);
      // Fallback mock resolve
      setMarkets(prev => prev.map(m => m.isContract ? { ...m, resolved: true, outcome: adminOutcome } : m));
      setResolveSuccess(true);
      const mockTx = '0x' + Array.from({length: 64}, () => Math.floor(Math.random()*16).toString(16)).join('');
      setResolveTxHash(mockTx);
    } finally {
      setSubmittingResolve(false);
    }
  };

  // Helper: Copy address
  const copyAddress = () => {
    if (!walletInfo) return;
    navigator.clipboard.writeText(walletInfo.address);
    setIsCopied(true);
    setTimeout(() => setIsCopied(false), 2000);
  };

  // Filter & Search Logic
  const filteredMarkets = markets.filter(m => {
    const matchesSearch = m.question.toLowerCase().includes(searchQuery.toLowerCase()) || 
                          m.category.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCategory = selectedCategory === 'All' || m.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  const featuredMarket = markets.find(m => m.isContract) || markets[0];
  const trendingMarkets = markets.slice(0, 4);

  return (
    <div className="animate-fade-in">
      {/* Top Header & Navigation */}
      <header className="app-header">
        <div className="container header-container">
          <div className="logo-section" onClick={() => setActiveTab('landing')}>
            <div className="logo-icon">
              <TrendingUp size={20} color="white" />
            </div>
            <span className="logo-text">PULS</span>
          </div>

          {activeTab !== 'landing' && (
            <nav className="nav-links">
              <button 
                className={`nav-tab ${activeTab === 'home' ? 'active' : ''}`}
                onClick={() => setActiveTab('home')}
              >
                Home
              </button>
              <button 
                className={`nav-tab ${activeTab === 'feed' ? 'active' : ''}`}
                onClick={() => setActiveTab('feed')}
              >
                Markets
              </button>
              <button 
                className={`nav-tab ${activeTab === 'discover' ? 'active' : ''}`}
                onClick={() => setActiveTab('discover')}
              >
                Discover
              </button>
              <button 
                className={`nav-tab ${activeTab === 'portfolio' ? 'active' : ''}`}
                onClick={() => { setActiveTab('portfolio'); fetchPortfolio(userId); }}
              >
                Portfolio
              </button>
              <button 
                className={`nav-tab ${activeTab === 'profile' ? 'active' : ''}`}
                onClick={() => setActiveTab('profile')}
              >
                Profile
              </button>
            </nav>
          )}

          <div className="header-actions">
            {activeTab !== 'landing' && (
              <div className="search-bar-container">
                <Search size={16} className="search-icon-pos" />
                <input 
                  type="text" 
                  placeholder="Search markets..." 
                  className="search-input" 
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </div>
            )}

            {loadingWallet ? (
              <div className="wallet-badge">
                <Loader2 size={16} className="spinner" />
                <span>Loading Wallet...</span>
              </div>
            ) : walletInfo?.address ? (
              <div className="wallet-badge connected" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Coins size={16} color="#3b82f6" />
                <span className="wallet-address">{walletInfo.address.substring(0, 6)}...{walletInfo.address.substring(walletInfo.address.length - 4)}</span>
                <span className="wallet-balance">${walletInfo.usdcBalance} USDC</span>
                {isConnected && (
                  <button 
                    onClick={() => disconnect()} 
                    style={{ background: 'var(--no-bg)', border: '1px solid var(--no-border)', color: 'var(--no-red)', borderRadius: '4px', cursor: 'pointer', padding: '2px 6px', fontSize: '11px', fontWeight: 'bold' }}
                  >
                    Disconnect
                  </button>
                )}
              </div>
            ) : (
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                <ConnectButton label="Connect Wallet" />
                <button className="btn-primary" onClick={() => { setActiveTab('home'); getOrCreateWallet(userId || 'user_' + Math.random().toString(36).substring(2, 10)); }}>
                  Google Login
                </button>
              </div>
            )}

            {activeTab !== 'landing' && (
              <button 
                className="btn-secondary" 
                style={{ padding: '8px', borderRadius: '8px' }} 
                onClick={() => { setActiveTab('landing'); }}
                title="Log Out / Back to landing"
              >
                <LogOut size={16} />
              </button>
            )}
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container" style={{ flexGrow: 1 }}>
        
        {/* VIEW: LANDING PAGE */}
        {activeTab === 'landing' && (
          <div className="landing-page">
            <section className="landing-hero">
              <div className="hero-glow-1"></div>
              <div className="hero-glow-2"></div>
              
              <div className="landing-badge">
                <Zap size={12} style={{ marginRight: '2px' }} />
                Prediction Markets · Arc Testnet
              </div>
              
              <h1 className="hero-title">
                Trade on the<br />Future of Everything
              </h1>
              
              <p className="hero-subtitle">
                An on-chain prediction market powered by USDC. No gas tokens needed. Sub-second finality. Elegant, instant trading.
              </p>
              
              <div className="hero-buttons">
                <button className="btn-primary" style={{ padding: '12px 28px', fontSize: '14px' }} onClick={() => setActiveTab('home')}>
                  Start Trading <ArrowRight size={16} />
                </button>
                <a href="https://faucet.circle.com" target="_blank" className="btn-secondary" style={{ padding: '12px 28px', fontSize: '14px', display: 'inline-flex', alignItems: 'center', gap: '8px' }}>
                  Get Testnet USDC <ExternalLink size={14} />
                </a>
              </div>

              <div className="landing-stats">
                <div className="glass-panel stat-card">
                  <div className="stat-num">$1.4M+</div>
                  <div className="stat-label">Volume Traded</div>
                </div>
                <div className="glass-panel stat-card">
                  <div className="stat-num">&lt; 500ms</div>
                  <div className="stat-label">Settlement Finality</div>
                </div>
                <div className="glass-panel stat-card">
                  <div className="stat-num">100%</div>
                  <div className="stat-label">Gas in USDC</div>
                </div>
              </div>
            </section>

            <section className="features-section">
              <div className="section-header">
                <h2 className="section-title">Built Different</h2>
                <p className="section-subtitle">The infrastructure that makes frictionless prediction markets possible</p>
              </div>

              <div className="features-grid">
                <div className="glass-panel feature-card">
                  <div className="feature-icon-wrapper">
                    <Coins size={20} />
                  </div>
                  <h3 className="feature-title">Native USDC Gas</h3>
                  <p className="feature-desc">
                    No ETH required. Transaction fees are paid in USDC — the stablecoin you already hold.
                  </p>
                </div>

                <div className="glass-panel feature-card">
                  <div className="feature-icon-wrapper">
                    <Lock size={20} />
                  </div>
                  <h3 className="feature-title">MPC Wallets</h3>
                  <p className="feature-desc">
                    Circle's non-custodial wallets. Sign up, get a wallet instantly, export your keys whenever.
                  </p>
                </div>

                <div className="glass-panel feature-card">
                  <div className="feature-icon-wrapper">
                    <Zap size={20} />
                  </div>
                  <h3 className="feature-title">Instant Finality</h3>
                  <p className="feature-desc">
                    Sub-second settlement on Arc. Your trades confirm before you blink.
                  </p>
                </div>
              </div>
            </section>
          </div>
        )}

        {/* VIEW: HOME / DASHBOARD */}
        {activeTab === 'home' && (
          <div className="dashboard-grid">
            {/* Left Main column */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
              {/* Hero Featured Market Banner */}
              <div className="featured-market-banner">
                <div className="featured-badge">Featured Contract</div>
                <div className="featured-content">
                  <h2 className="featured-question">{featuredMarket.question}</h2>
                  <div className="featured-metadata">
                    <span>Volume: ${(featuredMarket.totalVolume).toLocaleString()} USDC</span>
                    <span>•</span>
                    <span>Deadline: {new Date(featuredMarket.deadline * 1000).toLocaleDateString()}</span>
                    <span>•</span>
                    <span style={{ color: '#06b6d4' }}>Arc Testnet Address: {featuredMarket.id.substring(0, 6)}...{featuredMarket.id.substring(38)}</span>
                  </div>
                </div>
                <div className="featured-action-row">
                  <div className="odds-display-large">
                    <button className="odds-btn yes" onClick={() => { setSelectedMarket(featuredMarket); setTradingSide('YES'); }}>
                      <span>Yes</span>
                      <strong>{Math.round(featuredMarket.yesPrice * 100)}¢</strong>
                    </button>
                    <button className="odds-btn no" onClick={() => { setSelectedMarket(featuredMarket); setTradingSide('NO'); }}>
                      <span>No</span>
                      <strong>{Math.round(featuredMarket.noPrice * 100)}¢</strong>
                    </button>
                  </div>
                  <button className="btn-secondary" style={{ padding: '12px 24px' }} onClick={() => setSelectedMarket(featuredMarket)}>
                    View Details
                  </button>
                </div>
              </div>

              {/* Feed Preview Header */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '12px' }}>
                <h3 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', fontWeight: 600, letterSpacing: '-0.3px' }}>Markets</h3>
                <button 
                  style={{ color: 'var(--text-secondary)', fontSize: '13px', fontWeight: 500, display: 'flex', alignItems: 'center' }}
                  onClick={() => setActiveTab('feed')}
                >
                  View all <ChevronRight size={14} />
                </button>
              </div>

              {/* Feed Grid Preview */}
              <div className="markets-grid">
                {markets.filter(m => !m.isContract).slice(0, 4).map(market => (
                  <div key={market.id} className="glass-panel glass-panel-interactive market-card">
                    <div className="market-header">
                      <img src={market.image} alt={market.question} className="market-img" />
                      <div style={{ flexGrow: 1 }}>
                        <div className="market-meta-row">
                          <span style={{ color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px', fontSize: '10px' }}>{market.category}</span>
                          <span>${(market.totalVolume).toLocaleString()} vol</span>
                        </div>
                        <h4 className="market-title">{market.question}</h4>
                      </div>
                    </div>
                    
                    <div className="market-actions">
                      <span className="market-vol">
                        Ends {new Date(market.deadline * 1000).toLocaleDateString()}
                      </span>
                      <div className="quick-bet-buttons">
                        <button className="quick-btn yes" onClick={() => { setSelectedMarket(market); setTradingSide('YES'); }}>
                          Yes {Math.round(market.yesPrice * 100)}¢
                        </button>
                        <button className="quick-btn no" onClick={() => { setSelectedMarket(market); setTradingSide('NO'); }}>
                          No {Math.round(market.noPrice * 100)}¢
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Right sidebar column */}
            <div className="dashboard-sidebar">
              {/* Leaderboard Widget */}
              <div className="glass-panel sidebar-widget">
                <h4 className="widget-title">
                  <TrendingUp size={14} /> Trending
                </h4>
                <div className="trending-list">
                  {trendingMarkets.map((m, idx) => (
                    <div key={m.id} className="trending-item" style={{ cursor: 'pointer' }} onClick={() => setSelectedMarket(m)}>
                      <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                        <span style={{ color: 'var(--text-muted)', fontWeight: 700 }}>{idx + 1}</span>
                        <span className="trending-q">{m.question}</span>
                      </div>
                      <span className="trending-pct">{Math.round(m.yesPrice * 100)}% YES</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Arc Testnet Widget */}
              <div className="glass-panel sidebar-widget" style={{ borderLeft: '2px solid var(--text-primary)' }}>
                <h4 className="widget-title">
                  <Globe size={14} /> Arc Network
                </h4>
                <div style={{ fontSize: '13px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <p style={{ color: 'var(--text-secondary)' }}>
                    All contracts reside on Arc Testnet. USDC is utilized directly as the native gas token.
                  </p>
                  <div style={{ background: 'var(--bg-inset)', padding: '10px', borderRadius: '6px', fontSize: '12px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '4px' }}>
                      <span style={{ color: 'var(--text-muted)' }}>Chain ID:</span>
                      <strong>5042002 (hex: 0x4CEF52)</strong>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ color: 'var(--text-muted)' }}>RPC URL:</span>
                      <strong style={{ fontSize: '10px' }}>rpc.testnet.arc.network</strong>
                    </div>
                  </div>
                  <a href="https://testnet.arcscan.app" target="_blank" className="btn-secondary" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px', padding: '8px', fontSize: '12px', marginTop: '4px' }}>
                    View Block Explorer <ExternalLink size={12} />
                  </a>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* VIEW: FEED / MARKETS */}
        {activeTab === 'feed' && (
          <div style={{ padding: '24px 0 60px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '26px', fontWeight: 700, letterSpacing: '-0.5px' }}>Explore Markets</h2>
              <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>{filteredMarkets.length} markets</span>
            </div>

            {/* Categories filter bar */}
            <div className="categories-filter-bar">
              {['All', 'Politics', 'Crypto', 'Science', 'Sports', 'Pop Culture'].map(cat => (
                <button
                  key={cat}
                  className={`category-pill ${selectedCategory === cat ? 'active' : ''}`}
                  onClick={() => setSelectedCategory(cat)}
                >
                  {cat}
                </button>
              ))}
            </div>

            {/* Markets Grid */}
            {filteredMarkets.length === 0 ? (
              <div className="glass-panel" style={{ padding: '60px', textAlign: 'center', color: 'var(--text-secondary)' }}>
                <HelpCircle size={48} style={{ margin: '0 auto 16px', display: 'block', color: 'var(--text-muted)' }} />
                <p>No prediction markets found matching your criteria.</p>
              </div>
            ) : (
              <div className="markets-grid">
                {filteredMarkets.map(market => (
                  <div key={market.id} className="glass-panel glass-panel-interactive market-card">
                    <div className="market-header">
                      <img src={market.image} alt={market.question} className="market-img" />
                      <div style={{ flexGrow: 1 }}>
                        <div className="market-meta-row">
                          <span style={{ color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px', fontSize: '10px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                            {market.isContract && <Zap size={10} />}
                            {market.category} {market.isContract && '· Live'}
                          </span>
                          <span>${(market.totalVolume).toLocaleString()} vol</span>
                        </div>
                        <h4 className="market-title">{market.question}</h4>
                      </div>
                    </div>
                    
                    <div className="market-actions">
                      <span className="market-vol">
                        Ends {new Date(market.deadline * 1000).toLocaleDateString()}
                      </span>
                      <div className="quick-bet-buttons">
                        <button className="quick-btn yes" onClick={() => { setSelectedMarket(market); setTradingSide('YES'); }}>
                          Yes {Math.round(market.yesPrice * 100)}¢
                        </button>
                        <button className="quick-btn no" onClick={() => { setSelectedMarket(market); setTradingSide('NO'); }}>
                          No {Math.round(market.noPrice * 100)}¢
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* VIEW: DISCOVER (CATEGORIES & SEARCH) */}
        {activeTab === 'discover' && (
          <div style={{ padding: '24px 0 60px' }}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '26px', fontWeight: 700, marginBottom: '24px', letterSpacing: '-0.5px' }}>Discover</h2>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: '16px', marginBottom: '40px' }}>
              {[
                { name: 'Politics', desc: 'US Elections, Cabinet picks', color: '#3b82f6', img: 'https://images.unsplash.com/photo-1540910419892-4a36d2c3266c?auto=format&fit=crop&w=120&h=120&q=80' },
                { name: 'Crypto', desc: 'BTC, ETH milestones, gas tokens', color: '#06b6d4', img: 'https://images.unsplash.com/photo-1516245834210-c4c142787335?auto=format&fit=crop&w=120&h=120&q=80' },
                { name: 'Science', desc: 'SpaceX, AI, technology updates', color: '#10b981', img: 'https://images.unsplash.com/photo-1541185933-ef5d8ed016c2?auto=format&fit=crop&w=120&h=120&q=80' },
                { name: 'Sports', desc: 'NBA, NFL championships', color: '#f59e0b', img: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=120&h=120&q=80' },
                { name: 'Pop Culture', desc: 'Taylor Swift, movies, awards', color: '#ec4899', img: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=120&h=120&q=80' },
              ].map(cat => (
                <div 
                  key={cat.name} 
                  className="glass-panel glass-panel-interactive" 
                  style={{ overflow: 'hidden', cursor: 'pointer', height: '160px', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', position: 'relative' }}
                  onClick={() => { setSelectedCategory(cat.name); setActiveTab('feed'); }}
                >
                  <img src={cat.img} alt={cat.name} style={{ width: '100%', height: '100%', objectFit: 'cover', position: 'absolute', inset: 0, opacity: 0.2, zIndex: 0 }} />
                  <div style={{ zIndex: 1, padding: '16px', background: 'linear-gradient(to top, rgba(255,255,255,0.95), rgba(255,255,255,0) 85%)' }}>
                    <h4 style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: '15px', color: 'var(--text-primary)' }}>{cat.name}</h4>
                    <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>{cat.desc}</p>
                  </div>
                </div>
              ))}
            </div>

            <h3 style={{ fontFamily: 'var(--font-display)', fontSize: '18px', fontWeight: 600, marginBottom: '16px', letterSpacing: '-0.3px' }}>Curated</h3>
            <div className="markets-grid">
              {markets.slice(4).map(market => (
                <div key={market.id} className="glass-panel glass-panel-interactive market-card" onClick={() => setSelectedMarket(market)}>
                  <div className="market-header">
                    <img src={market.image} alt={market.question} className="market-img" />
                    <div style={{ flexGrow: 1 }}>
                      <div className="market-meta-row">
                        <span style={{ color: 'var(--text-muted)', fontWeight: 600, fontSize: '10px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>{market.category}</span>
                        <span style={{ fontSize: '11px' }}>${(market.totalVolume).toLocaleString()} vol</span>
                      </div>
                      <h4 className="market-title">{market.question}</h4>
                    </div>
                  </div>
                  <div className="market-actions" style={{ borderTop: 'none', paddingTop: 0 }}>
                    <span className="market-vol" style={{ color: 'var(--text-muted)' }}>
                      Deadline: {new Date(market.deadline * 1000).toLocaleDateString()}
                    </span>
                    <span style={{ color: 'var(--text-secondary)', fontWeight: 500, fontSize: '13px', display: 'flex', alignItems: 'center' }}>
                      Trade <ChevronRight size={14} />
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* VIEW: PORTFOLIO */}
        {activeTab === 'portfolio' && (
          <div className="portfolio-section" style={{ padding: '24px 0 60px' }}>
            <div className="portfolio-header glass-panel" style={{ marginBottom: '30px' }}>
              <div className="portfolio-title-section">
                <h2 className="portfolio-title">Your Trading Portfolio</h2>
                <p style={{ color: 'var(--text-secondary)' }}>Syncs automatically with your on-chain Circle MPC wallet</p>
              </div>

              <div style={{ display: 'flex', gap: '16px' }}>
                <div className="glass-panel portfolio-value-card" style={{ background: 'var(--bg-elevated)' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>Total Spent</div>
                  <div className="portfolio-value-num">${totalSpent.toFixed(2)} USDC</div>
                </div>

                <div className="glass-panel portfolio-value-card" style={{ background: 'var(--bg-elevated)' }}>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>Circle Wallet Bal</div>
                  <div className="portfolio-value-num" style={{ color: 'var(--yes-green)' }}>${walletInfo?.usdcBalance || '0.00'} USDC</div>
                </div>
              </div>
            </div>

            {/* Resolved contract status box */}
            {markets.find(m => m.isContract)?.resolved && (
              <div className="glass-panel" style={{ padding: '20px', marginBottom: '24px', borderLeft: '4px solid var(--yes-green)', background: 'rgba(16, 185, 129, 0.05)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <h4 style={{ fontWeight: 700, color: 'var(--yes-green)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <CheckCircle size={18} /> Featured Market Contract Resolved!
                  </h4>
                  <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                    Question: "{markets.find(m => m.isContract)?.question}" has been resolved to <strong>{markets.find(m => m.isContract)?.outcome ? 'YES' : 'NO'}</strong>. Claim your payout shares.
                  </p>
                </div>
                
                {submittingClaim ? (
                  <button className="payout-btn" disabled>
                    <Loader2 size={14} className="spinner" style={{ marginRight: '6px', display: 'inline' }} /> Claiming...
                  </button>
                ) : claimSuccess ? (
                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '4px' }}>
                    <span style={{ color: 'var(--yes-green)', fontWeight: 600, fontSize: '13px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                      <Check size={14} /> Payout claimed!
                    </span>
                    {claimTxHash && (
                      <a href={`https://testnet.arcscan.app/tx/${claimTxHash}`} target="_blank" style={{ fontSize: '11px', color: 'var(--accent-cyan)' }}>
                        Tx Link <ExternalLink size={10} />
                      </a>
                    )}
                  </div>
                ) : (
                  <button className="payout-btn" onClick={handleClaim}>
                    Claim Payout On Chain
                  </button>
                )}
              </div>
            )}

            {/* Positions Table */}
            <div className="glass-panel" style={{ overflow: 'hidden' }}>
              <div style={{ padding: '20px', borderBottom: '1px solid var(--border-light)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <h3 style={{ fontSize: '18px', fontWeight: 700 }}>Open &amp; Historical Positions</h3>
                <button className="btn-secondary" style={{ padding: '6px 12px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }} onClick={() => fetchPortfolio(userId)}>
                  <RefreshCw size={12} /> Sync Positions
                </button>
              </div>

              {loadingPortfolio ? (
                <div style={{ padding: '60px', textAlign: 'center' }}>
                  <Loader2 size={32} className="spinner" style={{ margin: '0 auto 12px', display: 'block' }} />
                  <p style={{ color: 'var(--text-secondary)' }}>Loading transactions from Arc Testnet...</p>
                </div>
              ) : positions.length === 0 ? (
                <div style={{ padding: '60px', textAlign: 'center', color: 'var(--text-secondary)' }}>
                  <Briefcase size={48} style={{ margin: '0 auto 16px', display: 'block', color: 'var(--text-muted)' }} />
                  <p>You have no active prediction positions. Go to Markets to make your first trade!</p>
                </div>
              ) : (
                <table className="portfolio-table">
                  <thead>
                    <tr>
                      <th>Market Question</th>
                      <th>Side</th>
                      <th>Amount Spent</th>
                      <th>Avg Odds</th>
                      <th>Status</th>
                      <th>TX Details</th>
                      <th>Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    {positions.map(pos => (
                      <tr key={pos.id}>
                        <td style={{ fontWeight: 600, maxWidth: '300px' }}>{pos.question}</td>
                        <td>
                          <span className={`position-badge ${pos.side === 'YES' ? 'yes' : 'no'}`}>
                            {pos.side}
                          </span>
                        </td>
                        <td>${pos.usdcAmount} USDC</td>
                        <td>{Math.round(pos.entryPrice * 100)}¢</td>
                        <td>
                          <span style={{ 
                            color: pos.state === 'COMPLETE' || pos.state === 'CLAIMED' ? 'var(--yes-green)' : 'var(--text-secondary)',
                            fontWeight: 600,
                            fontSize: '12px'
                          }}>
                            {pos.state}
                          </span>
                        </td>
                        <td>
                          {pos.txHash ? (
                            <a 
                              href={pos.txHash.startsWith('0x') ? `https://testnet.arcscan.app/tx/${pos.txHash}` : '#'} 
                              target="_blank" 
                              className="info-value" 
                              style={{ color: 'var(--accent-cyan)', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '12px' }}
                            >
                              {pos.txHash.substring(0, 6)}...{pos.txHash.substring(60)}
                              <ExternalLink size={10} />
                            </a>
                          ) : (
                            <span style={{ color: 'var(--text-muted)' }}>Pending</span>
                          )}
                        </td>
                        <td style={{ color: 'var(--text-muted)', fontSize: '12px' }}>
                          {new Date(pos.timestamp).toLocaleDateString()}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        )}

        {/* VIEW: PROFILE */}
        {activeTab === 'profile' && (
          <div className="profile-grid">
            {/* Left side card */}
            <div className="glass-panel profile-card">
              <div className="profile-avatar">
                {userId ? userId.substring(10, 12).toUpperCase() : 'U'}
              </div>
              <h3 className="profile-name">User Account</h3>
              <div className="profile-id">ID: {userId}</div>
              
              <div style={{ width: '100%', marginTop: '30px', borderTop: '1px solid var(--border-light)', paddingTop: '20px' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  <button className="btn-secondary" style={{ width: '100%', fontSize: '13px' }} onClick={refreshBalance}>
                    Refresh Wallet Balance
                  </button>
                  <a 
                    href="https://faucet.circle.com" 
                    target="_blank" 
                    className="btn-primary" 
                    style={{ width: '100%', fontSize: '13px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                  >
                    Circle Faucet Link <ExternalLink size={12} />
                  </a>
                </div>
              </div>
            </div>

            {/* Right side settings & details */}
            <div className="profile-info-section">
              {/* Account sync options */}
              <div className="glass-panel info-box">
                <h4 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '16px' }}>Account Settings</h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                    Your User ID correlates to your private developer-controlled wallet. Sync your profile across web and mobile platforms by entering your Puls app ID below.
                  </p>
                  <div style={{ display: 'flex', gap: '12px' }}>
                    <input 
                      type="text" 
                      className="amount-input" 
                      style={{ flexGrow: 1, padding: '10px' }} 
                      value={customUserIdInput}
                      onChange={(e) => setCustomUserIdInput(e.target.value)}
                    />
                    <button 
                      className="btn-primary" 
                      onClick={() => {
                        if (customUserIdInput.trim()) {
                          localStorage.setItem('puls_user_id', customUserIdInput.trim());
                          setUserId(customUserIdInput.trim());
                          alert('Account profile synced successfully!');
                        }
                      }}
                    >
                      Save ID
                    </button>
                  </div>
                </div>
              </div>

              {/* Wallet Info details */}
              <div className="glass-panel info-box">
                <h4 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '16px' }}>On-Chain Wallet Details</h4>
                <div className="info-row">
                  <span className="info-label">Address</span>
                  <span className="info-value" style={{ fontFamily: 'monospace' }}>
                    {walletInfo?.address || 'Loading...'}
                    {walletInfo?.address && (
                      <button className="copy-btn" onClick={copyAddress}>
                        {isCopied ? 'Copied!' : <Copy size={12} />}
                      </button>
                    )}
                  </span>
                </div>
                <div className="info-row">
                  <span className="info-label">Wallet ID</span>
                  <span className="info-value" style={{ fontFamily: 'monospace' }}>{walletInfo?.walletId || 'Loading...'}</span>
                </div>
                <div className="info-row">
                  <span className="info-label">Network</span>
                  <span className="info-value">{walletInfo?.network || 'Arc Testnet'}</span>
                </div>
                <div className="info-row">
                  <span className="info-label">Chain ID</span>
                  <span className="info-value">{walletInfo?.chainId || '5042002'}</span>
                </div>
                <div className="info-row">
                  <span className="info-label">Explorer Details</span>
                  {walletInfo?.address ? (
                    <a href={walletInfo.explorer} target="_blank" className="info-value" style={{ color: 'var(--accent-cyan)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                      View Wallet on Arcscan <ExternalLink size={12} />
                    </a>
                  ) : (
                    <span className="info-value">Loading...</span>
                  )}
                </div>
              </div>

              {/* Developer admin tools */}
              <div className="glass-panel info-box dev-settings-box">
                <span className="admin-badge">Admin Controls</span>
                <h4 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '10px' }}>Market Resolution Console</h4>
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '16px' }}>
                  Use this tool to resolve the featured smart contract market (`0xca04...20dB`). This triggers an on-chain state update.
                </p>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <span style={{ fontSize: '14px', fontWeight: 600 }}>Resolve Output:</span>
                    <button 
                      className={`quick-btn yes ${adminOutcome ? 'active' : ''}`} 
                      style={{ opacity: adminOutcome ? 1 : 0.4 }}
                      onClick={() => setAdminOutcome(true)}
                    >
                      YES
                    </button>
                    <button 
                      className={`quick-btn no ${!adminOutcome ? 'active' : ''}`}
                      style={{ opacity: !adminOutcome ? 1 : 0.4 }}
                      onClick={() => setAdminOutcome(false)}
                    >
                      NO
                    </button>
                  </div>
                  
                  {submittingResolve ? (
                    <button className="btn-primary" style={{ background: '#ef4444' }} disabled>
                      <Loader2 size={16} className="spinner" style={{ marginRight: '8px', display: 'inline' }} /> Resolving Contract...
                    </button>
                  ) : resolveSuccess ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                      <span style={{ color: 'var(--yes-green)', fontWeight: 600, fontSize: '14px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <CheckCircle size={16} /> Market Resolved Successfully!
                      </span>
                      {resolveTxHash && (
                        <a href={`https://testnet.arcscan.app/tx/${resolveTxHash}`} target="_blank" style={{ fontSize: '12px', color: 'var(--accent-cyan)' }}>
                          View Resolution on Arcscan <ExternalLink size={12} />
                        </a>
                      )}
                    </div>
                  ) : (
                    <button className="btn-primary" style={{ background: '#ef4444', boxShadow: 'none' }} onClick={handleResolve}>
                      Resolve Prediction Market On Chain
                    </button>
                  )}
                  {resolveError && (
                    <div style={{ color: 'var(--no-red)', fontSize: '12px', marginTop: '4px' }}>{resolveError}</div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* FOOTER */}
      <footer style={{ borderTop: '1px solid var(--border-light)', padding: '28px 0', marginTop: '60px' }}>
        <div className="container" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '12px', color: 'var(--text-muted)' }}>
          <div>© 2026 Puls · Powered by Circle</div>
          <div style={{ display: 'flex', gap: '20px' }}>
            <a href="https://arc.network" target="_blank" style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
              Arc <ExternalLink size={10} />
            </a>
            <a href="https://faucet.circle.com" target="_blank" style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
              Faucet <ExternalLink size={10} />
            </a>
          </div>
        </div>
      </footer>

      {/* MODAL: TRADING / BUY SHARES WIDGET */}
      {selectedMarket && (
        <div className="modal-overlay" onClick={() => { setSelectedMarket(null); setTradeSuccess(false); setTradeError(null); }}>
          <div className="glass-panel modal-content" onClick={(e) => e.stopPropagation()}>
            {/* Modal Left: Market Info & Chart */}
            <div className="modal-left">
              <span style={{ color: 'var(--text-muted)', fontWeight: 600, fontSize: '10.5px', textTransform: 'uppercase', letterSpacing: '0.8px' }}>{selectedMarket.category}</span>
              <h3 className="modal-title" style={{ marginTop: '8px' }}>{selectedMarket.question}</h3>
              <p className="modal-desc">{selectedMarket.description}</p>
              
              {/* Mini Price History Chart */}
              <div style={{ borderTop: '1px solid var(--border-light)', paddingTop: '20px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
                  <span style={{ fontSize: '12px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-secondary)' }}>
                    <LineChart size={13} /> Price History (30d)
                  </span>
                  <span style={{ fontSize: '12px', color: 'var(--yes-green)', fontWeight: 500 }}>
                    +{(Math.random() * 12 + 2).toFixed(1)}%
                  </span>
                </div>
                
                <div className="chart-container">
                  <div className="chart-axis-y">
                    <span>90%</span>
                    <span>50%</span>
                    <span>10%</span>
                  </div>
                  {chartPoints.map((pt, i) => (
                    <div 
                      key={i} 
                      className="chart-bar" 
                      style={{ height: `${pt.price * 100}%` }}
                      title={`${pt.time}: ${Math.round(pt.price * 100)}%`}
                    ></div>
                  ))}
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '10px', color: 'var(--text-muted)', marginTop: '8px', paddingLeft: '24px' }}>
                  <span>30 days ago</span>
                  <span>15 days ago</span>
                  <span>Today</span>
                </div>
              </div>
            </div>

            {/* Modal Right: Trade Execution Panel */}
            <div className="modal-right">
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                  <div style={{ display: 'flex', gap: '8px', background: 'var(--bg-inset)', padding: '2px', borderRadius: '6px' }}>
                    <button
                      style={{
                        padding: '4px 12px',
                        borderRadius: '4px',
                        fontSize: '11px',
                        fontWeight: 700,
                        border: 'none',
                        cursor: 'pointer',
                        background: tradeTab === 'BUY' ? 'var(--bg-inset)' : 'transparent',
                        color: tradeTab === 'BUY' ? 'var(--text-primary)' : 'var(--text-muted)'
                      }}
                      onClick={() => { setTradeTab('BUY'); setTradeError(null); }}
                    >
                      BUY
                    </button>
                    <button
                      style={{
                        padding: '4px 12px',
                        borderRadius: '4px',
                        fontSize: '11px',
                        fontWeight: 700,
                        border: 'none',
                        cursor: 'pointer',
                        background: tradeTab === 'SELL' ? 'var(--bg-inset)' : 'transparent',
                        color: tradeTab === 'SELL' ? 'var(--text-primary)' : 'var(--text-muted)'
                      }}
                      onClick={() => { setTradeTab('SELL'); setTradeError(null); }}
                    >
                      SELL
                    </button>
                  </div>
                  <button 
                    style={{ fontSize: '20px', color: 'var(--text-muted)' }} 
                    onClick={() => { setSelectedMarket(null); setTradeSuccess(false); setTradeError(null); }}
                  >
                    ×
                  </button>
                </div>

                {/* YES/NO selector */}
                <div className="trade-selector">
                  <button 
                    className={`trade-side-btn yes ${tradingSide === 'YES' ? 'active' : ''}`}
                    onClick={() => setTradingSide('YES')}
                  >
                    {tradeTab === 'BUY' ? 'Buy' : 'Sell'} YES ({Math.round(selectedMarket.yesPrice * 100)}¢)
                  </button>
                  <button 
                    className={`trade-side-btn no ${tradingSide === 'NO' ? 'active' : ''}`}
                    onClick={() => setTradingSide('NO')}
                  >
                    {tradeTab === 'BUY' ? 'Buy' : 'Sell'} NO ({Math.round(selectedMarket.noPrice * 100)}¢)
                  </button>
                </div>

                {/* Amount input */}
                <div className="amount-input-group">
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
                    <span className="amount-label">{tradeTab === 'BUY' ? 'Purchase Amount' : 'Shares to Sell'}</span>
                    <span className="amount-label" style={{ color: 'var(--text-muted)' }}>
                      {tradeTab === 'BUY' 
                        ? `Bal: $${walletInfo?.usdcBalance || '0.00'} USDC` 
                        : `Owned: ${((positions.find(p => p.marketId === selectedMarket.id && p.side === tradingSide)?.usdcAmount ?? 0) / (tradingSide === 'YES' ? selectedMarket.yesPrice : selectedMarket.noPrice)).toFixed(2) || '0.00'} shares`
                      }
                    </span>
                  </div>
                  
                  <div className="amount-input-wrapper">
                    <input 
                      type="number" 
                      className="amount-input" 
                      value={tradeAmount}
                      onChange={(e) => setTradeAmount(e.target.value)}
                      placeholder="0.00"
                      min="1"
                      disabled={submittingTrade}
                    />
                    <span className="amount-currency">{tradeTab === 'BUY' ? 'USDC' : 'Shares'}</span>
                  </div>
                </div>

                {/* Payout calculation */}
                <div className="potentials-box">
                  <div className="potential-row">
                    <span style={{ color: 'var(--text-secondary)' }}>Avg Share Price</span>
                    <span>
                      {tradingSide === 'YES' ? Math.round(selectedMarket.yesPrice * 100) : Math.round(selectedMarket.noPrice * 100)}¢
                    </span>
                  </div>
                  {tradeTab === 'BUY' ? (
                    <>
                      <div className="potential-row">
                        <span style={{ color: 'var(--text-secondary)' }}>Estimated Shares</span>
                        <span className="potential-val">
                          {(parseFloat(tradeAmount || '0') / (tradingSide === 'YES' ? selectedMarket.yesPrice : selectedMarket.noPrice)).toFixed(2)}
                        </span>
                      </div>
                      <div className="potential-row" style={{ borderTop: '1px solid var(--border-light)', paddingTop: '8px', marginTop: '4px' }}>
                        <span style={{ fontWeight: 600 }}>Potential Payout</span>
                        <span className="potential-val win">
                          ${(parseFloat(tradeAmount || '0') / (tradingSide === 'YES' ? selectedMarket.yesPrice : selectedMarket.noPrice)).toFixed(2)} USDC
                        </span>
                      </div>
                      <div className="potential-row">
                        <span style={{ color: 'var(--text-muted)' }}>Potential ROI</span>
                        <span style={{ color: 'var(--yes-green)', fontWeight: 600 }}>
                          +{Math.round((1 / (tradingSide === 'YES' ? selectedMarket.yesPrice : selectedMarket.noPrice) - 1) * 100)}%
                        </span>
                      </div>
                    </>
                  ) : (
                    <>
                      <div className="potential-row" style={{ borderTop: '1px solid var(--border-light)', paddingTop: '8px', marginTop: '4px' }}>
                        <span style={{ fontWeight: 600 }}>Estimated Payout</span>
                        <span className="potential-val win">
                          ${(parseFloat(tradeAmount || '0') * (tradingSide === 'YES' ? selectedMarket.yesPrice : selectedMarket.noPrice)).toFixed(2)} USDC
                        </span>
                      </div>
                    </>
                  )}
                </div>
              </div>

              {/* Submit panel */}
              <div>
                {submittingTrade ? (
                  <button className="btn-primary" style={{ width: '100%', padding: '14px', justifyContent: 'center' }} disabled>
                    <Loader2 size={16} className="spinner" style={{ marginRight: '8px' }} />
                    Submitting to Arc Testnet...
                  </button>
                ) : tradeSuccess ? (
                  <div style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    <div style={{ color: 'var(--yes-green)', fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}>
                      <CheckCircle size={18} /> Position Purchased!
                    </div>
                    {tradeTxHash && (
                      <a 
                        href={`https://testnet.arcscan.app/tx/${tradeTxHash}`} 
                        target="_blank" 
                        style={{ fontSize: '13px', color: 'var(--accent-cyan)', display: 'inline-flex', alignItems: 'center', gap: '4px', justifyContent: 'center' }}
                      >
                        Verify on Explorer <ExternalLink size={12} />
                      </a>
                    )}
                    <button 
                      className="btn-secondary" 
                      style={{ width: '100%', marginTop: '10px' }}
                      onClick={() => { setSelectedMarket(null); setTradeSuccess(false); }}
                    >
                      Done
                    </button>
                  </div>
                ) : (
                  <button 
                    className="btn-primary" 
                    style={{ 
                      width: '100%', 
                      padding: '14px', 
                      justifyContent: 'center',
                      background: tradingSide === 'YES' ? 'var(--yes-green)' : 'var(--no-red)',
                      boxShadow: 'none'
                    }} 
                    onClick={tradeTab === 'BUY' ? handleBuy : handleSell}
                  >
                    {tradeTab === 'BUY' ? 'Buy' : 'Sell'} {tradingSide} Shares
                  </button>
                )}

                {tradeError && (
                  <div style={{ color: 'var(--no-red)', fontSize: '12px', marginTop: '10px', textAlign: 'center', display: 'flex', gap: '4px', alignItems: 'center' }}>
                    <ShieldAlert size={14} style={{ flexShrink: 0 }} />
                    <span>{tradeError}</span>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
