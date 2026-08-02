import 'web3_wallet_bridge.dart';

bool hasBrowserWallet() {
  return false;
}

Future<WalletConnectResult> connectBrowserWallet() async {
  return WalletConnectResult(error: 'External browser wallets are not supported on this platform.');
}

void disconnectBrowserWallet() {}

String? getBrowserWalletAddress() {
  return null;
}

Future<WalletConnectResult> buyPositionOnChain(
  bool isYes,
  double amountUsdc,
  String contractAddress,
) async {
  return WalletConnectResult(error: 'External browser wallets are not supported on this platform.');
}

Future<WalletConnectResult> sellPositionOnChain(
  bool isYes,
  double shares,
  String contractAddress,
) async {
  return WalletConnectResult(error: 'External browser wallets are not supported on this platform.');
}

Future<WalletConnectResult> claimOnChain(String contractAddress) async {
  return WalletConnectResult(error: 'External browser wallets are not supported on this platform.');
}

Future<BridgeResult> bridgeUsdcToArc(double amountUsdc, {String? recipient, String? sourceKey}) async {
  return BridgeResult(error: 'Bridging is available on the web app with a browser wallet.');
}

Future<BridgeBalances> getBridgeBalances() async {
  return BridgeBalances(error: 'Bridging is available on the web app with a browser wallet.');
}

Future<UsdcBalanceResult> getUsdcBalance() async {
  return UsdcBalanceResult(error: 'Browser wallet required (web app).');
}

Future<GatewayBalanceResult> getGatewayBalance() async {
  return GatewayBalanceResult(error: 'Browser wallet required (web app).');
}

Future<InvestResult> investToAgent(String agentId, String amountUsdc) async {
  return InvestResult(error: 'Investing requires a browser wallet (web app).');
}

Future<WithdrawSignResult> signWithdrawMessage(String agentId) async {
  return WithdrawSignResult(error: 'Browser wallet required (web app).');
}
