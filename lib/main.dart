import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/mt_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // No signInAnonymously() here — every user of this app must
  // authenticate with a real account that's been added to /admins.
  runApp(const SigapAdminApp());
}

class SigapAdminApp extends StatelessWidget {
  const SigapAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIGAP Monitor',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935)),
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == null) {
          return const LoginPage();
        }
        return const MtDashboardPage();
      },
    );
  }
}