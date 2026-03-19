import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/network/api_client.dart';
import 'package:kinsaep_pos/core/network/cloud_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? store;
  final String subscriptionStatus;

  AuthState({
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.user,
    this.store,
    this.subscriptionStatus = CloudSubscriptionStatus.none,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    Map<String, dynamic>? store,
    String? subscriptionStatus,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      store: store ?? this.store,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    final settings = await DatabaseHelper.instance.getSettings();
    final token = await ApiClient.getToken();

    state = state.copyWith(
      isAuthenticated: token != null,
      subscriptionStatus:
          (settings['subscriptionStatus'] as String?) ??
          CloudSubscriptionStatus.none,
    );
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiClient.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await ApiClient.saveTokens(
          data['accessToken'] as String,
          data['refreshToken'] as String,
        );
        await _applyCloudSession(data);
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: data['user'] as Map<String, dynamic>?,
          store: data['store'] as Map<String, dynamic>?,
          subscriptionStatus:
              data['subscriptionStatus'] as String? ??
              CloudSubscriptionStatus.none,
        );
        return true;
      }

      final errorMsg = _errorFromBody(response.body, 'Login failed');
      state = state.copyWith(isLoading: false, error: errorMsg);
      return false;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: 'Network error: $error');
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiClient.post('/auth/register', data);

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        await ApiClient.saveTokens(
          responseData['accessToken'] as String,
          responseData['refreshToken'] as String,
        );
        await _applyCloudSession(responseData);
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: responseData['user'] as Map<String, dynamic>?,
          store: responseData['store'] as Map<String, dynamic>?,
          subscriptionStatus:
              responseData['subscriptionStatus'] as String? ??
              CloudSubscriptionStatus.none,
        );
        return true;
      }

      final errorMsg = _errorFromBody(response.body, 'Registration failed');
      state = state.copyWith(isLoading: false, error: errorMsg);
      return false;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: 'Network error: $error');
      return false;
    }
  }

  Future<void> logout() async {
    await ApiClient.clearTokens();
    await DatabaseHelper.instance.updateSettings({
      'syncEnabled': 0,
      'cloudMode': CloudMode.offlineOnly,
      'subscriptionStatus': CloudSubscriptionStatus.none,
      'remoteStoreId': null,
      'lastSyncAt': null,
    });
    state = state.copyWith(
      isAuthenticated: false,
      user: null,
      store: null,
      subscriptionStatus: CloudSubscriptionStatus.none,
    );
  }

  Future<void> _applyCloudSession(Map<String, dynamic> data) async {
    final store = data['store'] as Map<String, dynamic>?;
    final subscriptionStatus =
        data['subscriptionStatus'] as String? ?? CloudSubscriptionStatus.none;
    final cloudMode =
        subscriptionStatus == CloudSubscriptionStatus.active
            ? CloudMode.active
            : CloudMode.blocked;

    final settings = await DatabaseHelper.instance.getSettings();
    final hasExistingRemoteStoreId =
        (settings['remoteStoreId'] as String?)?.isNotEmpty == true;

    await DatabaseHelper.instance.updateSettings({
      'remoteStoreId': store?['id'],
      'subscriptionStatus': subscriptionStatus,
      'cloudMode': cloudMode,
      if (!hasExistingRemoteStoreId) 'syncEnabled': 0,
    });
  }

  String _errorFromBody(String body, String fallback) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error'] as String? ??
          fallback;
    } catch (_) {
      return fallback;
    }
  }
}
