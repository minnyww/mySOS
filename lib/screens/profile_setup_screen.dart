import '../services/db.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../models.dart';
import '../state/providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final role = ref.read(pendingRoleProvider);
    final uid = ref.read(authUidProvider).valueOrNull;
    final name = _name.text.trim();
    final phone = _phone.text.trim();

    if (uid == null || role == null) return;
    if (name.isEmpty) {
      setState(() => _error = 'กรุณากรอกชื่อ');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await mysosDb.collection('users').doc(uid).set({
        'role': role == Role.user ? 'user' : 'caregiver',
        'displayName': name,
        'phone': phone,
        'fcmTokens': [],
        'caregiverUids': [],
        'caringUids': [],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      // Router picks up the new profile and redirects automatically.
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'บันทึกไม่สำเร็จ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(pendingRoleProvider) ?? Role.user;
    final isCaregiver = role == Role.caregiver;

    return Scaffold(
      appBar: AppBar(title: Text('ข้อมูลของคุณ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            isCaregiver ? 'ตั้งค่าผู้ดูแล' : 'ตั้งค่าผู้ใช้',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'ชื่อจะแสดงในแจ้งเตือน SOS เพื่อให้ผู้ดูแลรู้ทันทีว่าใครขอความช่วยเหลือ',
            style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'ชื่อที่ต้องการให้แสดง *',
              hintText: 'เช่น คุณแม่, ป้าสมศรี, วิลาศ',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'เบอร์โทรศัพท์',
              hintText: '08XXXXXXXX',
              border: OutlineInputBorder(),
              helperText: 'ใช้ส่ง SMS แจ้งเตือนฉุกเฉิน (ผู้ดูแล) และกดโทรกลับได้',
            ),
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 15)),
            ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 24, width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('เริ่มใช้งาน'),
          ),
          const SizedBox(height: 12),
          Text(
            'ใช้งานเป็นบทบาท "${role.label}" — เปลี่ยนได้ภายหลังในหน้าตั้งค่า',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black45),
          ),
          Text(
            'เวอร์ชัน ${AppConfig.appName} 0.1',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black26),
          ),
        ],
      ),
    );
  }
}
