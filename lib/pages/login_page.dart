import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Replaces AdminLoginPage + kAdminPin entirely. There is no local PIN
// constant to extract from the binary — the only thing that decides
// whether this account can read /emergencies is whether its Firebase
// Auth uid is present in the /admins node, which is checked by the
// Realtime Database security rules (database.rules.json), not by
// anything in this file.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorText;
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorText = null;
      _submitting = true;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // AuthGate's authStateChanges listener handles navigation to
      // MtDashboardPage once sign-in succeeds — no explicit push here.
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = e.message ?? 'Login gagal');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Admin MT')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.lock_outline, size: 56, color: Color(0xFFE53935)),
            const SizedBox(height: 16),
            const Text('Masuk sebagai Admin', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText: 'Kata sandi',
                errorText: _errorText,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Masuk'),
            ),
          ],
        ),
      ),
    );
  }
}