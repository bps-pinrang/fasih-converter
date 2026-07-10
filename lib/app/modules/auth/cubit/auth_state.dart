import 'package:bps_sso_sdk/bps_sso_sdk.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final BPSUser user;
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}
