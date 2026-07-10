import 'package:auto_route/auto_route.dart';
import 'package:bps_sso_sdk/bps_sso_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/fasih_auth_repository.dart';
import '../../../di/injection.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

@RoutePage()
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    if (getIt<FasihAuthRepository>().isLoggedIn) {
      // Login completed while this view was open (race between async login
      // completion and a Flutter rebuild). Auto-pop so the caller continues.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.router.maybePop(true);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return BlocProvider(
      create: (_) => getIt<AuthCubit>(),
      child: const _LoginBody(),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.router.maybePop(true);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          context.read<AuthCubit>().resetToInitial();
        }
      },
      builder: (context, state) {
        final loading = state is AuthLoading;
        return Scaffold(
          appBar: AppBar(title: const Text('Login BPS SSO')),
          body: Center(
            child: loading
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Pilih akun SSO:',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => context
                              .read<AuthCubit>()
                              .login(context, BPSRealmType.internal),
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text('Pegawai BPS'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context
                              .read<AuthCubit>()
                              .login(context, BPSRealmType.external),
                          icon: const Icon(Icons.person_outlined),
                          label: const Text('Mitra Eksternal'),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
