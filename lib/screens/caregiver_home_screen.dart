import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/providers.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';

class CaregiverHomeScreen extends ConsumerWidget {
  const CaregiverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final caredUsers = ref.watch(caredUsersProvider).valueOrNull ?? [];
    final alerts = ref.watch(caregiverAlertsProvider).valueOrNull ?? [];
    final hasActive = alerts.any((a) => a.isActive);

    return Scaffold(
      appBar: AppBar(
        title: Text('ผู้ดูแล: ${profile?.displayName ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'ตั้งค่า',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('จับคู่กับผู้ใช้'),
        onPressed: () => _showPairOptions(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasActive)
            Card(
              color: AppTheme.sosRed.withValues(alpha: 0.08),
              child: const ListTile(
                leading: Icon(Icons.notifications_active,
                    color: AppTheme.sosRed, size: 32),
                title: Text('มี SOS ที่ยังไม่ได้รับทราบ!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                subtitle: Text('เลื่อนลงไปดูรายการด้านล่างและกด "รับทราบ"'),
              ),
            ),
          const SizedBox(height: 8),

          // --- Users in care ----------------------------------------------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: AppTheme.sosRed),
                      const SizedBox(width: 8),
                      Text('คนที่คุณดูแล (${caredUsers.length})',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (caredUsers.isEmpty)
                    const Text(
                      'ยังไม่มีผู้ใช้ — กดปุ่ม "จับคู่กับผู้ใช้" ด้านล่างเพื่อสแกน QR หรือกรอกรหัส',
                      style: TextStyle(color: Colors.black54, fontSize: 15, height: 1.4),
                    )
                  else
                    ...caredUsers.map((u) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person),
                          title: Text(u.displayName ?? 'ผู้ใช้',
                              style: const TextStyle(fontSize: 17)),
                          subtitle: u.isLineLinked
                              ? const Text('ครบทุกช่องทาง (Push/LINE/SMS)')
                              : const Text('Push + SMS'),
                          trailing: u.phone != null && u.phone!.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.phone),
                                  onPressed: () =>
                                      launchUrl(Uri.parse('tel:${u.phone}')),
                                )
                              : null,
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Alert feed --------------------------------------------------
          const Text('แจ้งเตือนทั้งหมด',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (alerts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'ยังไม่มีรายการแจ้งเตือน — เมื่อผู้ที่คุณดูแลกด SOS รายการจะปรากฏที่นี่พร้อมแจ้งเตือนบนหน้าจอ',
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
              ),
            )
          else
            ...alerts.map((a) => Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: a.isActive
                          ? AppTheme.sosRed
                          : Colors.black26,
                      foregroundColor: Colors.white,
                      child: Text(a.userName.isNotEmpty ? a.userName[0] : '?'),
                    ),
                    title: Text('${a.userName} ขอความช่วยเหลือ',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: StatusChip(alert: a),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/alerts/${a.id}'),
                  ),
                )),
        ],
      ),
    );
  }

  void _showPairOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, size: 32),
              title: const Text('สแกน QR', style: TextStyle(fontSize: 18)),
              subtitle: const Text('สแกน QR จากหน้าจอของผู้ใช้'),
              onTap: () {
                Navigator.pop(context);
                context.push('/scan');
              },
            ),
            ListTile(
              leading: const Icon(Icons.dialpad, size: 32),
              title: const Text('กรอกรหัส 6 หลัก', style: TextStyle(fontSize: 18)),
              subtitle: const Text('พิมพ์รหัสที่ผู้ใช้แสดงบนหน้าจอ'),
              onTap: () {
                Navigator.pop(context);
                context.push('/enter-code');
              },
            ),
          ],
        ),
      ),
    );
  }
}
