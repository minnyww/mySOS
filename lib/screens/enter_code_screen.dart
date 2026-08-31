import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Manual 6-digit pair code entry for caregivers.
class EnterCodeScreen extends StatefulWidget {
  const EnterCodeScreen({super.key});

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'กรุณากรอกรหัส 6 หลัก (ตัวเลขเท่านั้น)');
      return;
    }
    setState(() => _error = null);
    context.pushReplacement('/pair/$code');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('กรอกรหัสเชื่อมต่อ')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ให้ผู้ใช้เปิดหน้า "เชื่อมต่อผู้ดูแล" ในแอปของเขา แล้วอ่านรหัส 6 หลักมากรอกที่นี่',
              style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: 12),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '000000',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 15)),
              ),
            FilledButton(onPressed: _submit, child: const Text('ถัดไป')),
          ],
        ),
      ),
    );
  }
}
