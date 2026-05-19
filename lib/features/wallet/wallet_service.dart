import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart' show backendUrl;
const _backendUrl = backendUrl;

final _supabase = Supabase.instance.client;

class WalletState {
  const WalletState({
    this.userId,
    this.walletId,
    this.walletAddress,
    this.usdcBalance = '0',
    this.isLoading = false,
    this.error,
  });

  final String? userId;
  final String? walletId;
  final String? walletAddress;
  final String usdcBalance;
  final bool isLoading;
  final String? error;

  bool get hasWallet => walletId != null;

  WalletState copyWith({
    String? userId,
    String? walletId,
    String? walletAddress,
    String? usdcBalance,
    bool? isLoading,
    String? error,
  }) =>
      WalletState(
        userId: userId ?? this.userId,
        walletId: walletId ?? this.walletId,
        walletAddress: walletAddress ?? this.walletAddress,
        usdcBalance: usdcBalance ?? this.usdcBalance,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class WalletService extends ChangeNotifier {
  WalletState _state = const WalletState();
  WalletState get state => _state;
  Timer? _refreshTimer;

  WalletService() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && _state.userId == null) {
        _onSignedIn(data.session!.user);
      } else if (data.session == null) {
        _refreshTimer?.cancel();
        _state = const WalletState();
        notifyListeners();
      }
    });
    final existing = _supabase.auth.currentSession;
    if (existing != null) _onSignedIn(existing.user);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => refreshBalance());
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    _setState(_state.copyWith(isLoading: true, error: null));
    try {
      // On web, redirectTo must be the current app URL (not localhost)
      String? redirectTo;
      if (kIsWeb) {
        // Use the current page origin so it works on any deployment
        redirectTo = Uri.base.origin;
      } else {
        redirectTo = 'io.supabase.puls://login-callback';
      }
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _state = const WalletState();
    notifyListeners();
  }

  void _onSignedIn(User user) {
    final userId = 'supabase_${user.id}';
    _setState(_state.copyWith(userId: userId, isLoading: true));
    _getOrCreateWallet(userId);
  }

  // ── Wallet — auto-created by backend, no WebView needed ───────────────────

  Future<void> _getOrCreateWallet(String userId) async {
    try {
      final res = await _post('/api/wallet/get-or-create', {'userId': userId});
      final address = res['address'] as String? ?? '';
      final balance = res['usdcBalance'] as String? ?? '0';
      _setState(_state.copyWith(
        walletId: res['walletId'] as String,
        walletAddress: address,
        usdcBalance: balance,
        isLoading: false,
      ));
      if (address.isNotEmpty) {
        _fetchBalanceFromChain(address);
      } else {
        debugPrint('[Puls] wallet address empty from backend, balance: $balance');
      }
      _startPeriodicRefresh();
    } catch (e) {
      debugPrint('[Puls] get-or-create error: $e');
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> refreshBalance() async {
    if (_state.userId == null) return;
    if (_state.walletAddress != null && _state.walletAddress!.isNotEmpty) {
      await _fetchBalanceFromChain(_state.walletAddress!);
      return;
    }
    // No address yet — reload wallet info from backend
    await reloadWallet();
  }

  /// Re-fetches wallet info from backend (address + balance).
  Future<void> reloadWallet() async {
    if (_state.userId == null) return;
    try {
      final res = await _post('/api/wallet/get-or-create', {'userId': _state.userId!});
      final address = res['address'] as String? ?? '';
      _setState(_state.copyWith(
        walletId: res['walletId'] as String? ?? _state.walletId,
        walletAddress: address.isNotEmpty ? address : _state.walletAddress,
        usdcBalance: res['usdcBalance'] as String? ?? _state.usdcBalance,
        isLoading: false,
      ));
      if (address.isNotEmpty) _fetchBalanceFromChain(address);
    } catch (_) {}
  }

  /// Reads USDC balance directly from Arc Testnet via eth_call — no backend needed.
  Future<void> _fetchBalanceFromChain(String address) async {
    const rpc = 'https://rpc.testnet.arc.network';
    const usdc = '0x3600000000000000000000000000000000000000';
    final padded = address.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
    final data = '0x70a08231$padded';
    try {
      final res = await http.post(
        Uri.parse(rpc),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'eth_call',
          'params': [{'to': usdc, 'data': data}, 'latest'],
          'id': 1,
        }),
      ).timeout(const Duration(seconds: 8));
      final result = (jsonDecode(res.body) as Map)['result'] as String?;
      if (result != null && result.length >= 2) {
        final raw = BigInt.tryParse(result.replaceFirst('0x', ''), radix: 16) ?? BigInt.zero;
        final balance = raw / BigInt.from(1000000);
        _setState(_state.copyWith(usdcBalance: balance.toStringAsFixed(2)));
      }
    } catch (e) {
      debugPrint('[Puls] chain balance error: $e');
      // Fallback to backend balance endpoint
      try {
        if (_state.userId != null) {
          final res = await _get('/api/wallet/balance', {'userId': _state.userId!});
          _setState(_state.copyWith(
            usdcBalance: res['usdcBalance'] as String? ?? _state.usdcBalance,
          ));
        }
      } catch (_) {}
    }
  }

  // ── Trade ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> buyPosition({
    required bool isYes,
    required double usdcAmount,
    required String question,
    double entryPrice = 0.5,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    if (!_state.hasWallet) throw Exception('No wallet');

    final res = await _post('/api/trade/buy', {
      'userId': _state.userId!,
      'side': isYes ? 'YES' : 'NO',
      'usdcAmount': usdcAmount.toStringAsFixed(6),
      'question': question,
      'entryPrice': entryPrice.toStringAsFixed(4),
    });

    Future.delayed(const Duration(seconds: 3), refreshBalance);
    return res;
  }

  Future<Map<String, dynamic>> claimWinnings() async {
    if (_state.userId == null) throw Exception('Not signed in');
    final res = await _post('/api/trade/claim', {'userId': _state.userId!});
    // Refresh immediately + again after 8s for on-chain confirmation
    refreshBalance();
    Future.delayed(const Duration(seconds: 8), refreshBalance);
    return res;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setState(WalletState s) {
    _state = s;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_backendUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> params) async {
    final uri = Uri.parse('$_backendUrl$path').replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }
}
