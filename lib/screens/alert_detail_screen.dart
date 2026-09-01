import '../services/db.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/alert_map.dart';
import '../widgets/channel_result.dart';
import '../widgets/status_chip.dart';

/// Shared by both roles: full details of one SOS alert.
class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({super.key, required this.alertId});
  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertAsync = ref.watch(_alertStreamProvider(alertId));

    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียด SOS')),
      body: alertAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('อ่านข้อมูลไม่ได้: $e')),
        data: (alert) {
          if (alert == null) {
            return const Center(child: Text('ไม่พบรายการนี้'));
          }
          return _Body(alert: alert);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.alert});
  final AlertRecord alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(userProfileProvider).valueOrNull;
    final isCaregiver = me?.role == Role.caregiver;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: alert.isActive
              ? AppTheme.sosRed.withValues(alpha: 0.08)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  alert.status == 'acked' ? Icons.check_circle : Icons.sos,
                  size: 64,
                  color: alert.status == 'acked' ? AppTheme.okGreen : AppTheme.sosRed,
                ),
                const SizedBox(height: 8),
                Text(
                  '${alert.userName} ขอความช่วยเหลือ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                StatusChip(alert: alert),
                const SizedBox(height: 6),
                Text(
                  _timeText(alert.ts) + (alert.source == 'widget' ? ' • จาก Widget' : ''),
                  style: const TextStyle(color: Colors.black54),
                ),
                if (alert.ackByName != null) ...[
                  const SizedBox(height: 8),
                  Text('รับทราบโดย ${alert.ackByName}',
                      style: const TextStyle(
                          color: AppTheme.okGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- In-app live map ------------------------------------------------
        if (alert.hasLocation) ...[
          AlertMapCard(alert: alert),
          const SizedBox(height: 8),
        ],

        // --- Actions ------------------------------------------------------
        if (alert.hasLocation)
          OutlinedButton.icon(
            icon: const Icon(Icons.map),
            label: const Text('เปิดตำแหน่งใน Google Maps'),
            onPressed: () => launchUrl(
              Uri.parse(alert.mapUrl()),
              mode: LaunchMode.externalApplication,
            ),
          ),
        const SizedBox(height: 8),
        if (isCaregiver) ...[
          _CallButton(userId: alert.userId),
          const SizedBox(height: 8),
          if (alert.isActive)
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.okGreen,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check),
              label: const Text('รับทราบ — กำลังไปช่วย'),
              onPressed: () async {
                final me = ref.read(userProfileProvider).valueOrNull;
                if (me == null) return;
                try {
                  await ref
                      .read(alertServiceProvider)
                      .ackAlert(alert.id, me);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('ทำรายการไม่สำเร็จ: $e')),
                    );
                  }
                }
              },
            ),
        ] else if (alert.isActive)
          OutlinedButton.icon(
            icon: const Icon(Icons.close),
            label: const Text('ยกเลิกการขอความช่วยเหลือ'),
            onPressed: () async {
              try {
                await ref.read(alertServiceProvider).cancelAlert(alert.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ยกเลิกไม่สำเร็จ: $e')),
                  );
                }
              }
            },
          ),

        const SizedBox(height: 24),
        const Text('สถานะการส่งแต่ละช่องทาง',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ChannelResult(alert: alert),
        if (alert.channels.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'รายละเอียด: ${alert.channels}',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ],
    );
  }

  String _timeText(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year + 543} ${two(dt.hour)}:${two(dt.minute)} น.';
  }
}

/// Loads the alert owner's phone (rules allow caregivers of that user).
class _CallButton extends StatefulWidget {
  const _CallButton({required this.userId});
  final String userId;

  @override
  State<_CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<_CallButton> {
  String? _phone;

  @override
  void initState() {
    super.initState();
    mysosDb
        .collection('users')
        .doc(widget.userId)
        .get()
        .then((doc) {
      if (mounted && doc.exists) {
        setState(() => _phone = doc.data()?['phone'] as String?);
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_phone == null || _phone!.isEmpty) {
      return const SizedBox.shrink();
    }
    return FilledButton.icon(
      icon: const Icon(Icons.phone),
      label: Text('โทรหา $_phone'),
      onPressed: () => launchUrl(Uri.parse('tel:$_phone')),
    );
  }
}

final _alertStreamProvider =
    StreamProvider.autoDispose.family<AlertRecord?, String>((ref, alertId) {
  return mysosDb
      .collection('alerts')
      .doc(alertId)
      .snapshots()
      .map((doc) => doc.exists ? AlertRecord.fromSnapshot(doc) : null);
});
