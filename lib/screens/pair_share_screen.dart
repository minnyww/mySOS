import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config.dart';
import '../services/pairing_service.dart';
import '../state/providers.dart';
import '../theme.dart';

/// User side of pairing: show QR + 6-digit code, watch until linked.
class PairShareScreen extends ConsumerStatefulWidget {
  const PairShareScreen({super.key});

  @override
  ConsumerState<PairShareScreen> createState() => _PairShareScreenState();
}

class _PairShareScreenState extends ConsumerState<PairShareScreen> {
  String? _code;
  int? _expiresAt;
  bool _loading = false;
  String? _error;
  Timer? _expiryTicker;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _expiryTicker?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    final uid = ref.read(authUidProvider).valueOrNull;
    if (uid == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await ref
          .read(pairingServiceProvider)
          .createPairCode(uid);
      setState(() {
        _code = code;
        _expiresAt = DateTime.now()
            .add(AppConfig.pairCodeTtl)
            .millisecondsSinceEpoch;
        _loading = false;
      });
      _expiryTicker?.cancel();
      _expiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {}); // refresh remaining-time text
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'สร้างรหัสไม่สำเร็จ ลองอีกครั้ง';
      });
    }
  }

  String get _remaining {
    if (_expiresAt == null) return '';
    final left = (_expiresAt! - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    if (left <= 0) return 'หมดอายุแล้ว';
    final m = left ~/ 60;
    final s = left % 60;
    return 'หมดอายุในอีก $m:${s.toString().padLeft(2, '0')} นาที';
  }

  bool get _expired {
    if (_expiresAt == null) return false;
    return DateTime.now().millisecondsSinceEpoch > _expiresAt!;
  }

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(pairingServiceProvider);
    final status = _code != null
        ? pairing.watchPairStatus(_code!).map((s) => s == 'missing' && !_expired ? 'pending' : s)
        : const Stream<String>.empty();

    return Scaffold(
      appBar: AppBar(title: const Text('เชื่อมต่อผู้ดูแล')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'ให้ผู้ดูแลทำอย่างใดอย่างหนึ่ง:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            '① สแกน QR ด้านล่างด้วยกล้องในแอปนี้ (หน้าผู้ดูแล → สแกน QR)\n'
            '② หรือกรอกรหัส 6 หลักในหน้า "กรอกรหัส"',
            style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 24),
          StreamBuilder<String>(
            stream: status,
            builder: (context, snap) {
              final s = snap.data ?? 'pending';
              if (s == 'linked') {
                return _SuccessCard(onNewCode: _generate);
              }
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _expired ? Colors.grey : AppTheme.sosRed,
                        width: 2,
                      ),
                    ),
                    child: _loading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _expired
                            ? Column(
                                children: [
                                  const Icon(Icons.timer_off,
                                      size: 56, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  const Text('รหัสหมดอายุแล้ว',
                                      style: TextStyle(fontSize: 18)),
                                  const SizedBox(height: 8),
                                  FilledButton(
                                    onPressed: _generate,
                                    child: const Text('สร้างรหัสใหม่'),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  QrImageView(
                                    data: PairingService.qrPayload(_code!),
                                    version: QrVersions.auto,
                                    size: 210,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: AppTheme.sosRed,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Color(0xFF212121),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _code!,
                                    style: const TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_remaining,
                                      style: const TextStyle(
                                          color: Colors.black54, fontSize: 14)),
                                ],
                              ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('สร้างรหัสใหม่'),
                    onPressed: _loading ? null : _generate,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.onNewCode});
  final VoidCallback onNewCode;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.okGreen.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.okGreen, size: 64),
            const SizedBox(height: 12),
            const Text(
              'เชื่อมต่อสำเร็จ!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'ผู้ดูแลจะได้รับแจ้งเตือนเมื่อคุณกด SOS',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('เสร็จสิ้น'),
            ),
            TextButton(onPressed: onNewCode, child: const Text('เชื่อมต่อคนเพิ่ม')),
          ],
        ),
      ),
    );
  }
}
