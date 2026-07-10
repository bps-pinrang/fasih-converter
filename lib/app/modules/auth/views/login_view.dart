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
    final auth = getIt<FasihAuthRepository>();
    if (auth.isLoggedIn) {
      return _LoggedInBody(user: auth.currentUser!);
    }
    return BlocProvider(
      create: (_) => getIt<AuthCubit>(),
      child: const _LoginBody(),
    );
  }
}

class _LoggedInBody extends StatelessWidget {
  const _LoggedInBody({required this.user});

  final BPSUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akun BPS SSO')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.account_circle, size: 64, color: Colors.blueGrey),
            const SizedBox(height: 16),
            Text(
              user.fullName,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              user.username,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              user.realmDisplayName,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.router.maybePop(true),
              child: const Text('Lanjutkan'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await getIt<FasihAuthRepository>().logout();
                if (context.mounted) context.router.maybePop(false);
              },
              child: const Text('Ganti Akun'),
            ),
          ],
        ),
      ),
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
