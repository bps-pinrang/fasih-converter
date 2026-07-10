import 'dart:convert';

import 'package:bps_sso_sdk/bps_sso_sdk.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/env/app_env.dart';

const _kUserKey = 'fasih_sso_user';
const _kRealmKey = 'fasih_sso_realm';

@singleton
class FasihAuthRepository {
  final SharedPreferences _prefs;

  BPSUser? _currentUser;

  FasihAuthRepository(this._prefs) {
    _initSdk();
    _restoreUser();
  }

  BPSUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null && !_currentUser!.isTokenExpired;

  void _initSdk() {
    BPSSsoClient.instance.initialize(
      config: BPSSsoConfig.create(
        appName: 'fasih',
        internalClientId: AppEnv.fasihClientIdInternal,
        externalClientId: AppEnv.fasihClientIdEksternal,
        baseUrl: AppEnv.fasihSsoBaseUrl,
      ),
    );
  }

  void _restoreUser() {
    final json = _prefs.getString(_kUserKey);
    final realmStr = _prefs.getString(_kRealmKey);
    if (json == null || realmStr == null) return;
    try {
      final realm = realmStr == 'external'
          ? BPSRealmType.external
          : BPSRealmType.internal;
      _currentUser =
          BPSUser.fromJson(jsonDecode(json) as Map<String, dynamic>, realm);
    } catch (_) {
      _prefs.remove(_kUserKey);
    }
  }

  Future<BPSUser> login(BuildContext context, BPSRealmType realm) async {
    final user = await BPSSsoClient.instance.login(
      context: context,
      realmType: realm,
    );
    _currentUser = user;
    await _prefs.setString(_kUserKey, jsonEncode(user.toJson()));
    await _prefs.setString(_kRealmKey, realm.name);
    return user;
  }

  Future<void> logout() async {
    final user = _currentUser;
    _currentUser = null;
    await _prefs.remove(_kUserKey);
    await _prefs.remove(_kRealmKey);
    if (user != null) {
      await BPSSsoClient.instance.logout(user);
    }
  }

  /// Returns a valid access token, refreshing automatically if needed.
  Future<String?> getValidToken() async {
    var user = _currentUser;
    if (user == null) return null;

    if (BPSSsoClient.instance.shouldRefreshToken(user)) {
      try {
        user = await BPSSsoClient.instance.refreshToken(user);
        _currentUser = user;
        await _prefs.setString(_kUserKey, jsonEncode(user.toJson()));
      } catch (_) {
        return null;
      }
    }

    return user.accessToken;
  }
}
