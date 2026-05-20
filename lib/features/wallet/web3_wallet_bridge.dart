import 'dart:js_interop';

/// JS interop bridge for browser wallet (MetaMask, etc.) on Flutter web.
/// Communicates with the JS functions defined in web/index.html.

@JS('connectBrowserWallet')
external JSPromise<JSString> _jsConnectBrowserWallet();

@JS('disconnectBrowserWallet')
external JSString _jsDisconnectBrowserWallet();

@JS('getBrowserWalletAddress')
external JSString _jsGetBrowserWalletAddress();

@JS('hasBrowserWallet')
external JSBoolean _jsHasBrowserWallet();

@JS('buyPositionOnChain')
external JSPromise<JSString> _jsBuyPositionOnChain(JSBoolean isYes, JSString amountUsdc, JSString contractAddress);

@JS('sellPositionOnChain')
external JSPromise<JSString> _jsSellPositionOnChain(JSBoolean isYes, JSString shares, JSString contractAddress);

@JS('claimOnChain')
external JSPromise<JSString> _jsClaimOnChain(JSString contractAddress);

/// Result of a wallet connect or contract call attempt.
class WalletConnectResult {
  final String? address;
  final String? txHash;
  final String? error;
  WalletConnectResult({this.address, this.txHash, this.error});
}

/// Check if a browser wallet (MetaMask) is available.
bool hasBrowserWallet() {
  try {
    return _jsHasBrowserWallet().toDart;
  } catch (_) {
    return false;
  }
}

/// Connect to browser wallet. Returns address on success, error on failure.
Future<WalletConnectResult> connectBrowserWallet() async {
  try {
    final resultJson = (await _jsConnectBrowserWallet().toDart).toDart;
    if (resultJson.contains('"error"')) {
      final errMsg = _extractJsonValue(resultJson, 'error');
      return WalletConnectResult(error: errMsg);
    }
    final address = _extractJsonValue(resultJson, 'address');
    return WalletConnectResult(address: address);
  } catch (e) {
    return WalletConnectResult(error: e.toString());
  }
}

/// Disconnect browser wallet.
void disconnectBrowserWallet() {
  try {
    _jsDisconnectBrowserWallet();
  } catch (_) {}
}

/// Get current connected wallet address, or null.
String? getBrowserWalletAddress() {
  try {
    final addr = _jsGetBrowserWalletAddress().toDart;
    return addr.isEmpty ? null : addr;
  } catch (_) {
    return null;
  }
}

/// Run on-chain buy position transaction.
Future<WalletConnectResult> buyPositionOnChain(bool isYes, double amountUsdc, String contractAddress) async {
  try {
    final resultJson = (await _jsBuyPositionOnChain(
      isYes.toJS,
      amountUsdc.toString().toJS,
      contractAddress.toJS,
    ).toDart).toDart;
    
    if (resultJson.contains('"error"')) {
      final errMsg = _extractJsonValue(resultJson, 'error');
      return WalletConnectResult(error: errMsg);
    }
    final txHash = _extractJsonValue(resultJson, 'txHash');
    return WalletConnectResult(txHash: txHash);
  } catch (e) {
    return WalletConnectResult(error: e.toString());
  }
}

/// Run on-chain sell position transaction.
Future<WalletConnectResult> sellPositionOnChain(bool isYes, double shares, String contractAddress) async {
  try {
    final resultJson = (await _jsSellPositionOnChain(
      isYes.toJS,
      shares.toString().toJS,
      contractAddress.toJS,
    ).toDart).toDart;
    
    if (resultJson.contains('"error"')) {
      final errMsg = _extractJsonValue(resultJson, 'error');
      return WalletConnectResult(error: errMsg);
    }
    final txHash = _extractJsonValue(resultJson, 'txHash');
    return WalletConnectResult(txHash: txHash);
  } catch (e) {
    return WalletConnectResult(error: e.toString());
  }
}

/// Run on-chain claim winnings transaction.
Future<WalletConnectResult> claimOnChain(String contractAddress) async {
  try {
    final resultJson = (await _jsClaimOnChain(contractAddress.toJS).toDart).toDart;
    
    if (resultJson.contains('"error"')) {
      final errMsg = _extractJsonValue(resultJson, 'error');
      return WalletConnectResult(error: errMsg);
    }
    final txHash = _extractJsonValue(resultJson, 'txHash');
    return WalletConnectResult(txHash: txHash);
  } catch (e) {
    return WalletConnectResult(error: e.toString());
  }
}

/// Simple JSON value extractor (avoids importing dart:convert for this small use).
String _extractJsonValue(String json, String key) {
  final pattern = '"$key":"';
  final start = json.indexOf(pattern);
  if (start == -1) return '';
  final valueStart = start + pattern.length;
  final valueEnd = json.indexOf('"', valueStart);
  if (valueEnd == -1) return '';
  return json.substring(valueStart, valueEnd);
}
