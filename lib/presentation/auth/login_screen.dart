import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:proctor/presentation/common/section_card.dart';
import 'package:proctor/state/auth_controller.dart';

/// Login screen for super admin and proctor users.
class LoginScreen extends StatefulWidget {
  /// Creates the login screen.
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Proctor App',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Login sebagai super admin atau proctor untuk melihat sesi aktif dan kode OTP lokal.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Masuk',
                  subtitle:
                      'Flow login sekarang memakai repository in-memory sebagai scaffold sebelum Firebase.',
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: Text(_isSubmitting ? 'Memproses...' : 'Login'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _DemoAccountsCard(),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Belum punya akun? Daftar sebagai proctor'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final authController = context.read<AuthController>();
    final success = await authController.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email atau password tidak valid.')),
    );
  }
}

class _DemoAccountsCard extends StatelessWidget {
  const _DemoAccountsCard();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'Akun Demo',
      subtitle:
          'Dipakai untuk scaffold lokal sebelum auth Firebase disambungkan.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Super Admin: admin@proctor.local / admin123'),
          SizedBox(height: 8),
          Text('Proctor: proctor@proctor.local / proctor123'),
          SizedBox(height: 8),
          Text('Pending: pending@proctor.local / pending123'),
        ],
      ),
    );
  }
}
