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

  WalletService() {
    // Only use the listener — skip the manual existing session check to avoid double-firing
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && _state.userId == null) {
        _onSignedIn(data.session!.user);
      } else if (data.session == null) {
        _state = const WalletState();
        notifyListeners();
      }
    });
    // Restore on cold start
    final existing = _supabase.auth.currentSession;
    if (existing != null) _onSignedIn(existing.user);
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    _setState(_state.copyWith(isLoading: true, error: null));
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.puls://login-callback',
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
      _setState(_state.copyWith(
        walletId: res['walletId'] as String,
        walletAddress: res['address'] as String,
        usdcBalance: res['usdcBalance'] as String? ?? '0',
        isLoading: false,
      ));
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> refreshBalance() async {
    if (_state.userId == null) return;
    _setState(_state.copyWith(isLoading: true));
    try {
      final res = await _get('/api/wallet/balance', {'userId': _state.userId!});
      _setState(_state.copyWith(
        usdcBalance: res['usdcBalance'] as String? ?? '0',
        isLoading: false,
      ));
    } catch (_) {
      _setState(_state.copyWith(isLoading: false));
    }
  }

  // ── Trade ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> buyPosition({
    required bool isYes,
    required double usdcAmount,
    required String question,
  }) async {
    if (_state.userId == null) throw Exception('Not signed in');
    if (!_state.hasWallet) throw Exception('No wallet');

    final res = await _post('/api/trade/buy', {
      'userId': _state.userId!,
      'side': isYes ? 'YES' : 'NO',
      'usdcAmount': usdcAmount.toStringAsFixed(6),
      'question': question,
    });

    // Refresh balance after trade
    Future.delayed(const Duration(seconds: 3), refreshBalance);
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
