import 'package:bps_sso_sdk/bps_sso_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../data/repositories/fasih_auth_repository.dart';
import 'auth_state.dart';

@injectable
class AuthCubit extends Cubit<AuthState> {
  final FasihAuthRepository _auth;

  AuthCubit(this._auth) : super(const AuthInitial());

  Future<void> login(BuildContext context, BPSRealmType realm) async {
    emit(const AuthLoading());
    try {
      final user = await _auth.login(context, realm);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    emit(const AuthInitial());
  }
}
