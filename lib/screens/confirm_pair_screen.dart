import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/pairing_service.dart';
import '../state/providers.dart';
import '../theme.dart';
class ConfirmPairScreen extends ConsumerStatefulWidget {
  const ConfirmPairScreen({super.key, required this.code});
  final String code;

  @override
  ConsumerState<ConfirmPairScreen> createState() => _ConfirmPairScreenState();
}

class _ConfirmPairScreenState extends ConsumerState<ConfirmPairScreen> {
  bool _accepting = false;
  String? _error;
  Timer? _successTimer;

  Future<void> _accept() async {
    final uid = ref.read(authUidProvider).valueOrNull;
    if (uid == null) return;
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      await ref
          .read(pairingServiceProvider)
          .acceptPairCode(widget.code, uid);
      // Status stream below flips to 'linked' when the Cloud Function finishes.
    } on PairCodeException catch (e) {
      setState(() {
        _accepting = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _accepting = false;
        _error = 'เกิดข้อผิดพลาด กรุณาลองใหม่';
      });
    }
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(pairingServiceProvider);
    final status = pairing.watchPairStatus(widget.code);

    return Scaffold(
      appBar: AppBar(title: const Text('ยืนยันการเชื่อมต่อ')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<String>(
          stream: status,
          builder: (context, snap) {
            final s = snap.data ?? 'pending';
            if (s == 'linked') {
              // Pop back home shortly after showing success.
              _successTimer ??= Timer(const Duration(milliseconds: 1500), () {
                if (mounted) context.go('/caregiver');
              });
              return _buildSuccess();
            }
            final claimed = s == 'missing';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text('รหัสที่ได้รับ',
                    style: TextStyle(color: Colors.black54, fontSize: 15)),
                Text(
                  widget.code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 10),
                ),
                const SizedBox(height: 16),
                Text(
                  claimed && _accepting
                      ? 'กำลังเชื่อมต่อ...'
                      : 'กดยืนยันเพื่อรับแจ้งเตือน SOS จากผู้ใช้รายนี้',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 15)),
                  ),
                FilledButton(
                  onPressed: _accepting ? null : _accept,
                  child: _accepting
                      ? const SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('ยืนยันการเชื่อมต่อ'),
                ),
                TextButton(
                  onPressed: () => context.go('/caregiver'),
                  child: const Text('ยกเลิก'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppTheme.okGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 56),
          ),
          const SizedBox(height: 16),
          const Text('เชื่อมต่อสำเร็จ!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('คุณจะได้รับแจ้งเตือน SOS จากผู้ใช้รายนี้',
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
