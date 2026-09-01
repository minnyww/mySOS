import '../services/db.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../services/fcm_service.dart';
import '../state/providers.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _lineCode;
  bool _generatingCode = false;
  bool _diagRunning = false;
  List<String>? _diagLines;

  Future<void> _runFcmDiagnostics() async {
    final uid = ref.read(authUidProvider).valueOrNull;
    if (uid == null) return;
    setState(() => _diagRunning = true);
    final lines = await diagnoseFcm(uid);
    if (mounted) {
      setState(() {
        _diagLines = lines;
        _diagRunning = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = ref.read(authUidProvider).valueOrNull;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await mysosDb.collection('users').doc(uid).update({
        'displayName': _name.text.trim(),
        'phone': _phone.text.trim(),
        'lastActiveAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('บันทึกแล้ว')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    }
    setState(() => _saving = false);
  }

  Future<void> _generateLineCode() async {
    final uid = ref.read(authUidProvider).valueOrNull;
    if (uid == null) return;
    setState(() => _generatingCode = true);
    try {
      final code =
          await ref.read(pairingServiceProvider).createLineLinkCode(uid);
      setState(() => _lineCode = code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('สร้างรหัสไม่สำเร็จ')));
      }
    }
    setState(() => _generatingCode = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile != null) {
      _name.text = _name.text.isEmpty ? (profile.displayName ?? '') : _name.text;
      _phone.text = _phone.text.isEmpty ? (profile.phone ?? '') : _phone.text;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- Profile -----------------------------------------------------
          const Text('ข้อมูลของฉัน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'ชื่อที่แสดง', border: OutlineInputBorder()),
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'เบอร์โทรศัพท์',
              border: OutlineInputBorder(),
              helperText: 'ผู้ดูแล: ใช้รับ SMS • ผู้ใช้: ให้ผู้ดูแลกดโทรกลับได้',
            ),
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 24, width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('บันทึก'),
          ),
          const Divider(height: 40),

          // --- LINE linking (caregiver) -----------------------------------
          if (profile?.role == Role.caregiver) ...[
            const Text('รับแจ้งเตือนผ่าน LINE',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (profile?.isLineLinked ?? false)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.check_circle, color: AppTheme.okGreen),
                  title: Text('เชื่อมต่อ LINE แล้ว'),
                  subtitle: Text('จะได้รับข้อความ SOS ผ่าน LINE ที่เชื่อมไว้'),
                ),
              )
            else ...[
              const Text(
                'รับ SOS ผ่าน LINE นอกเหนือจากแจ้งเตือนในแอป:\n'
                '① เพิ่มเพื่อน LINE OA ของ MySOS\n'
                '② สร้างรหัส แล้วส่งรหัสนั้นไปในแชท OA',
                style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 12),
              if (AppConfig.lineOaUrl.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble),
                  label: const Text('เพิ่มเพื่อน LINE OA'),
                  onPressed: () => launchUrl(
                    Uri.parse(AppConfig.lineOaUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              const SizedBox(height: 8),
              if (_lineCode != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      const Text('ส่งรหัสนี้ไปในแชท OA (อายุ 10 นาที):'),
                      const SizedBox(height: 4),
                      Text(
                        _lineCode!,
                        style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8),
                      ),
                    ],
                  ),
                ),
              FilledButton.tonalIcon(
                icon: _generatingCode
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.link),
                label: Text(_lineCode == null
                    ? 'สร้างรหัสเชื่อมต่อ LINE'
                    : 'สร้างรหัสใหม่'),
                onPressed: _generatingCode ? null : _generateLineCode,
              ),
            ],
            const Divider(height: 40),
          ],

          // --- Notification test -------------------------------------------
          const Text('ทดสอบระบบแจ้งเตือน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.notifications_active),
            label: const Text('ทดสอบเสียง/แจ้งเตือนบนเครื่องนี้'),
            onPressed: () => showTestNotification(),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            icon: _diagRunning
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.health_and_safety),
            label: const Text('ตรวจสอบการแจ้งเตือน (วินิจฉัย)'),
            onPressed: _diagRunning ? null : _runFcmDiagnostics,
          ),
          if (_diagLines != null) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _diagLines!
                      .map((l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(l,
                                style: const TextStyle(
                                    fontSize: 14, height: 1.4)),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
          const Divider(height: 40),

          // --- Widget hint ---------------------------------------------------
          const Text('ปุ่มลัดบนหน้าจอ (Widget)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'กดค้างที่หน้าจอหลักของโทรศัพท์ → เลือก Widget → หา "${AppConfig.appName} SOS" '
            'เพื่อวางปุ่ม SOS ไว้กดฉุกเฉินโดยไม่ต้องเปิดแอป',
            style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 24),
          Text(
            '${AppConfig.appName} เวอร์ชัน 0.1',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black38),
          ),
        ],
      ),
    );
  }
}
