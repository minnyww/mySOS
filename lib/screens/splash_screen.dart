import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.sosRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.sosRed.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.sos, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 24),
            Text(
              AppConfig.appName,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
