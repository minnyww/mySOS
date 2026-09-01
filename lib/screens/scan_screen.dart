import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/pairing_service.dart';

/// QR scanner for caregivers: detects mysos://pair/<code> links or a bare
/// 6-digit code, then jumps to the confirm screen.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _navigating = false;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Check only — let mobile_scanner do the actual requesting, so the two
  // permission flows never race each other into a PlatformException.
  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      setState(() => _permanentlyDenied = true);
    }
  }

  Future<void> _restartCamera() async {
    try {
      await _controller.stop();
    } catch (_) {
      // Stop may fail if the camera never started — that is fine here.
    }
    _controller.dispose();
    // Give CameraX a beat to release the camera before re-opening it.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _permanentlyDenied = false;
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    });
    await _checkCameraPermission();
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
          Positioned.fill(
            child: _permanentlyDenied
                ? _buildPermissionDenied()
                : MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) {
                      if (error.errorCode ==
                          MobileScannerErrorCode.permissionDenied) {
                        return _buildPermissionDenied();
                      }
                      return _buildCameraError(error);
                    },
                  ),
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
                    style: TextStyle(
                        color: Colors.white, fontSize: 16, height: 1.4),
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

  Widget _buildPermissionDenied() {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_camera_front,
                  color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              const Text(
                'ไม่ได้รับอนุญาตให้ใช้กล้อง',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'เปิดสิทธิ์กล้องของแอปใน การตั้งค่า แล้วกลับมาสแกนใหม่\nหรือกรอกรหัส 6 หลักเองด้านล่าง',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('เปิดการตั้งค่า'),
                onPressed: () => openAppSettings(),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _restartCamera,
                child:
                    const Text('ลองเปิดกล้องอีกครั้ง', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraError(MobileScannerException error) {
    // Surface the underlying cause — genericError alone hides the real
    // platform message (e.g. "camera already in use").
    final details = error.errorDetails;
    final cause = (details?.message ?? details?.code)?.toString() ?? '';
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(
                cause.isEmpty
                    ? 'เปิดกล้องไม่สำเร็จ ลองอีกครั้ง\n(${error.errorCode.name})'
                    : 'เปิดกล้องไม่สำเร็จ\n$cause',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _restartCamera,
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
