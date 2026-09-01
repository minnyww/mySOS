import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/channel_result.dart';

/// SOS flow: 3-2-1 countdown (cancellable) -> send -> live delivery status.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key, required this.source});
  final String source; // 'app' | 'widget'

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

enum _Phase { countdown, sending, sent }

class _SosScreenState extends ConsumerState<SosScreen> {
  _Phase _phase = _Phase.countdown;
  int _count = AppConfig.sosCountdown.inSeconds;
  Timer? _timer;
  String? _alertId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_count <= 1) {
        t.cancel();
        _fire();
      } else {
        setState(() => _count--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _cancel() {
    // PopScope blocks maybePop during the countdown, so route home directly.
    _timer?.cancel();
    context.go('/user');
  }

  Future<void> _fire() async {
    setState(() => _phase = _Phase.sending);
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) {
      setState(() => _error = 'ยังตั้งค่าโปรไฟล์ไม่เสร็จ');
      return;
    }
    try {
      final doc =
          await ref.read(alertServiceProvider).sendSos(profile: profile, source: widget.source);
      setState(() {
        _phase = _Phase.sent;
        _alertId = doc.id;
      });
    } catch (e) {
      setState(() => _error = 'ส่งไม่สำเร็จ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _Phase.countdown,
      child: Scaffold(
        backgroundColor: _phase == _Phase.countdown
            ? AppTheme.sosRedDark
            : Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: _buildBody()),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.countdown:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('กำลังส่ง SOS ในอีก',
                style: TextStyle(color: Colors.white70, fontSize: 20)),
            const SizedBox(height: 8),
            Text('$_count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 96,
                    fontWeight: FontWeight.w800)),
            const Text('วินาที',
                style: TextStyle(color: Colors.white70, fontSize: 20)),
            const SizedBox(height: 40),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                minimumSize: const Size(200, 64),
              ),
              icon: const Icon(Icons.close, size: 28),
              label: const Text('ยกเลิก', style: TextStyle(fontSize: 22)),
              onPressed: _cancel,
            ),
          ],
        );
      case _Phase.sending:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 6),
            SizedBox(height: 24),
            Text('กำลังส่ง SOS ถึงผู้ดูแล...',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ],
        );
      case _Phase.sent:
        if (_error != null) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.sosRed),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              FilledButton(onPressed: _fire, child: const Text('ลองส่งใหม่')),
            ],
          );
        }
        return _SentView(alertId: _alertId!);
    }
  }
}

/// Live status of the sent alert — delivery channels and acks.
class _SentView extends ConsumerWidget {
  const _SentView({required this.alertId});
  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(_alertStreamProvider(alertId)).valueOrNull;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          record?.status == 'acked' ? Icons.check_circle : Icons.campaign,
          size: 72,
          color: record?.status == 'acked' ? AppTheme.okGreen : AppTheme.sosRed,
        ),
        const SizedBox(height: 12),
        Text(
          switch (record?.status) {
            'acked' => 'ผู้ดูแลรับทราบแล้ว ✅',
            'rate_limited' => 'ส่งถี่เกินไป — รอ 1 นาทีแล้วกดอีกครั้ง',
            'no_caregivers' => 'ยังไม่มีผู้ดูแลเชื่อมต่อ',
            'cancelled' => 'ยกเลิกแล้ว',
            _ => 'ส่ง SOS แล้ว — กำลังแจ้งผู้ดูแล',
          },
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        ChannelResult(alert: record),
        const SizedBox(height: 32),
        if (record?.isActive ?? false)
          OutlinedButton.icon(
            icon: const Icon(Icons.close),
            label: const Text('ยกเลิกการขอความช่วยเหลือ'),
            onPressed: () async {
              try {
                await ref.read(alertServiceProvider).cancelAlert(alertId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ยกเลิกไม่สำเร็จ: $e')),
                  );
                }
              }
            },
          ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('กลับหน้าหลัก'),
        ),
      ],
    );
  }
}

final _alertStreamProvider = StreamProvider.autoDispose
    .family<AlertRecord, String>((ref, alertId) {
  return ref.watch(alertServiceProvider).watchAlert(alertId);
});
