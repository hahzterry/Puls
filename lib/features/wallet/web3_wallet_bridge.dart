import 'web3_wallet_bridge_stub.dart'
    if (dart.library.js_interop) 'web3_wallet_bridge_web.dart' as impl;

/// Result of a wallet connect or contract call attempt.
class WalletConnectResult {
  final String? address;
  final String? txHash;
  final String? error;
  WalletConnectResult({this.address, this.txHash, this.error});
}

/// Check if a browser wallet (MetaMask) is available.
bool hasBrowserWallet() => impl.hasBrowserWallet();

/// Connect to browser wallet. Returns address on success, error on failure.
Future<WalletConnectResult> connectBrowserWallet() => impl.connectBrowserWallet();

/// Disconnect browser wallet.
void disconnectBrowserWallet() => impl.disconnectBrowserWallet();

/// Get current connected wallet address, or null.
String? getBrowserWalletAddress() => impl.getBrowserWalletAddress();

/// Run on-chain buy position transaction.
Future<WalletConnectResult> buyPositionOnChain(bool isYes, double amountUsdc, String contractAddress) =>
    impl.buyPositionOnChain(isYes, amountUsdc, contractAddress);

/// Run on-chain sell position transaction.
Future<WalletConnectResult> sellPositionOnChain(bool isYes, double shares, String contractAddress) =>
    impl.sellPositionOnChain(isYes, shares, contractAddress);

/// Run on-chain claim winnings transaction.
Future<WalletConnectResult> claimOnChain(String contractAddress) =>
    impl.claimOnChain(contractAddress);

/// Bridge USDC from a chosen EVM testnet → Arc via Circle CCTP (Forwarding Service).
Future<BridgeResult> bridgeUsdcToArc(double amountUsdc, {String? recipient, String? sourceKey}) =>
    impl.bridgeUsdcToArc(amountUsdc, recipient: recipient, sourceKey: sourceKey);

/// Read the connected wallet's USDC balance on every supported source chain.
Future<BridgeBalances> getBridgeBalances() => impl.getBridgeBalances();

/// USDC balance on one source chain.
class BridgeBalance {
  final String key;
  final String name;
  final double usdc;
  final String symbol;
  final String explorer;
  BridgeBalance({required this.key, required this.name, required this.usdc, required this.symbol, required this.explorer});
}

/// All source-chain balances for the connected wallet.
class BridgeBalances {
  final String? address;
  final List<BridgeBalance> chains;
  final String? error;
  BridgeBalances({this.address, this.chains = const [], this.error});
}

/// Result of a CCTP bridge attempt.
class BridgeResult {
  final String? arcTxHash;
  final String? burnTxHash;
  final bool pending;
  final String? error;
  BridgeResult({this.arcTxHash, this.burnTxHash, this.pending = false, this.error});
}

/// Wallet USDC balance on Arc (micro USDC units).
class UsdcBalanceResult {
  final String? microUsdc;
  final String? error;
  UsdcBalanceResult({this.microUsdc, this.error});
}

/// Circle Gateway balance for the wallet (micro USDC units).
class GatewayBalanceResult {
  final String? availableMicro;
  final String? totalMicro;
  final String? error;
  GatewayBalanceResult({this.availableMicro, this.totalMicro, this.error});
}

/// Outcome of investing into an agent via x402.
class InvestResult {
  final Map<String, dynamic>? data;
  final String? depositTx;
  final String? error;
  final bool alreadySettled;
  InvestResult({this.data, this.depositTx, this.error, this.alreadySettled = false});
}

/// EIP-191 withdraw message signature.
class WithdrawSignResult {
  final String? address;
  final String? signature;
  final String? error;
  WithdrawSignResult({this.address, this.signature, this.error});
}

/// Wallet USDC balance on Arc.
Future<UsdcBalanceResult> getUsdcBalance() => impl.getUsdcBalance();

/// Circle Gateway balance for the connected wallet.
Future<GatewayBalanceResult> getGatewayBalance() => impl.getGatewayBalance();

/// Invest `amountUsdc` into an agent: top up Gateway wallet if needed, then
/// settle the x402 payment. Returns the backend response on success.
Future<InvestResult> investToAgent(String agentId, String amountUsdc) =>
    impl.investToAgent(agentId, amountUsdc);

/// Sign `puls-invest:withdraw:<agentId>` (EIP-191 personal message).
Future<WithdrawSignResult> signWithdrawMessage(String agentId) =>
    impl.signWithdrawMessage(agentId);
