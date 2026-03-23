import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/ideas_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Firebase not configured yet — run flutterfire configure to fix this.
    // The app will launch but auth/database features won't work.
    debugPrint('Firebase init skipped: $e');
  }
  runApp(const ReelMindApp());
}

class ReelMindApp extends StatelessWidget {
  const ReelMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => IdeasProvider()),
      ],
      child: MaterialApp(
        title: 'ReelMind',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C63FF),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const _RootRouter(),
      ),
    );
  }
}

// Set to true to skip login and go straight to the dashboard for UI development.
const bool kBypassAuth = false;

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    if (kBypassAuth) return const DashboardScreen();
    final auth = context.watch<AuthProvider>();
    if (auth.isSignedIn) return const DashboardScreen();
    return const AuthScreen();
  }
}
