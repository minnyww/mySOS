import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';

class RoleSelectScreen extends ConsumerWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.sos, size: 64, color: AppTheme.sosRed),
              const SizedBox(height: 8),
              Text(
                'ยินดีต้อนรับสู่ ${AppConfig.appName}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'คุณจะใช้แอปนี้ในบทบาทใด?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              _RoleCard(
                icon: Icons.elderly,
                title: 'ฉันต้องการความช่วยเหลือ',
                subtitle: 'กดปุ่ม SOS เมื่อฉุกเฉิน แล้วผู้ดูแลจะรับแจ้งทันที\nผ่าน แอป / LINE / SMS',
                onTap: () => _pick(context, ref, Role.user),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.volunteer_activism,
                title: 'ฉันเป็นผู้ดูแล',
                subtitle: 'รับแจ้งเตือนเมื่อคนที่คุณดูแลกดขอความช่วยเหลือ',
                onTap: () => _pick(context, ref, Role.caregiver),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pick(BuildContext context, WidgetRef ref, Role role) {
    ref.read(pendingRoleProvider.notifier).state = role;
    context.go('/profile-setup');
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 44, color: AppTheme.sosRed),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 15, color: Colors.black54, height: 1.35)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
