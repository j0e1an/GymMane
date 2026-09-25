import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../platform/web_auth.dart';
import '../theme/app_theme.dart';

class WebSignInApp extends StatelessWidget {
  const WebSignInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymMane',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const WebSignInScreen(),
    );
  }
}

class WebSignInScreen extends StatelessWidget {
  const WebSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gc = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0908),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('GymMane',
                    textAlign: TextAlign.center,
                    style: AppTheme.f(36, weight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 10),
                Text(t.signInBody,
                    textAlign: TextAlign.center,
                    style: AppTheme.f(15, weight: FontWeight.w500, color: const Color(0xFF9A9A9A), height: 1.4)),
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A1713),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: startGoogleSignIn,
                  child: Text(t.signInWithGoogle,
                      style: AppTheme.f(15, weight: FontWeight.w700, color: const Color(0xFF1A1713))),
                ),
                const SizedBox(height: 8),
                Text(t.signInTitle,
                    textAlign: TextAlign.center,
                    style: AppTheme.f(12, weight: FontWeight.w600, color: gc.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
