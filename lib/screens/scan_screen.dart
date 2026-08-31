import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/pairing_service.dart';

/// QR scanner for caregivers: detects mysos://pair/<code> links or a bare
/// 6-digit code, then jumps to the confirm screen.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _navigating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_navigating) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final code = PairingService.parseQrPayload(raw) ??
          (RegExp(r'^\d{6}$').hasMatch(raw.trim()) ? raw.trim() : null);
      if (code != null) {
        _navigating = true;
        context.pushReplacement('/pair/$code');
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('สแกน QR ของผู้ใช้'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'เปิด/ปิดไฟฉาย',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'เล็งกล้องไปที่ QR บนหน้าจอของผู้ใช้\n(หน้า "เชื่อมต่อผู้ดูแล")',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pushReplacement('/enter-code'),
                    child: const Text('สแกนไม่ได้? กรอกรหัส 6 หลักเอง',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
