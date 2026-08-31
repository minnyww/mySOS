import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../state/providers.dart';
import '../theme.dart';

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final caregivers = ref.watch(caregiversProvider).valueOrNull ?? [];
    final alerts = ref.watch(userAlertsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('สวัสดี ${profile?.displayName ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'ตั้งค่า',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- SOS button -------------------------------------------------
          Semantics(
            button: true,
            label: 'ปุ่มขอความช่วยเหลือฉุกเฉิน',
            child: InkWell(
              borderRadius: BorderRadius.circular(120),
              onTap: () => context.push('/sos?source=app'),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.sosRed,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.sosRed.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sos, color: Colors.white, size: 72),
                      Text(
                        'กดขอความช่วยเหลือ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'กดแล้วมีเวลา ${AppConfig.sosCountdown.inSeconds} วินาที ให้ยกเลิก\n'
            'หรือกดจาก Widget บนหน้าจอหลักได้เลย',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),

          // --- Caregivers -------------------------------------------------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group, color: AppTheme.sosRed),
                      const SizedBox(width: 8),
                      Text(
                        'ผู้ดูแลของคุณ (${caregivers.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (caregivers.isEmpty)
                    const Text(
                      'ยังไม่มีผู้ดูแล — เชื่อมต่อเลย ไม่งั้น SOS จะไม่ถึงใคร',
                      style: TextStyle(color: Colors.black54, fontSize: 15),
                    )
                  else
                    ...caregivers.map((c) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person),
                          title: Text(c.displayName ?? 'ผู้ดูแล',
                              style: const TextStyle(fontSize: 17)),
                          subtitle: c.isLineLinked
                              ? const Text('รับแจ้งเตือนครบทุกช่องทาง')
                              : const Text('แอป + SMS'),
                          trailing: c.phone != null && c.phone!.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.phone),
                                  onPressed: () =>
                                      launchUrl(Uri.parse('tel:${c.phone}')),
                                )
                              : null,
                        )),
                  const SizedBox(height: 4),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.qr_code),
                    label: Text(caregivers.isEmpty ? 'เชื่อมต่อผู้ดูแล' : 'เพิ่มผู้ดูแล'),
                    onPressed: () => context.push('/pair'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Alert history ----------------------------------------------
          if (alerts.isNotEmpty) ...[
            const Text('ประวัติการขอความช่วยเหลือ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...alerts.map((a) => Card(
                  child: ListTile(
                    leading: Icon(
                      a.status == 'acked' ? Icons.check_circle : Icons.sos,
                      color: a.status == 'acked'
                          ? AppTheme.okGreen
                          : AppTheme.sosRed,
                    ),
                    title: Text(a.statusLabel, style: const TextStyle(fontSize: 17)),
                    subtitle: Text(_timeText(a.ts)),
                    onTap: () => context.push('/alerts/${a.id}'),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _timeText(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year + 543} ${two(dt.hour)}:${two(dt.minute)} น.';
  }
}
