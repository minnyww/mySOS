import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';

/// Shown when Firebase is not configured yet (missing native config files).
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${AppConfig.appName} — ตั้งค่าเบื้องต้น')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Icon(Icons.build_circle, size: 64, color: AppTheme.sosRed),
          SizedBox(height: 12),
          Text(
            'ยังเชื่อมต่อ Firebase ไม่ได้',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'แอปต้องมีไฟล์ตั้งค่า Firebase ก่อนเริ่มใช้งาน ทำตามขั้นตอนใน README '
            '(หัวข้อ "ตั้งค่า Firebase") แล้วรันแอปใหม่:',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          _StepCard(
            step: '1',
            text: 'สร้างโปรเจกต์ Firebase และเปิด Anonymous Authentication + Cloud Firestore',
          ),
          _StepCard(
            step: '2',
            text: 'รัน: flutterfire configure --project=<project-id> '
                '(สร้างไฟล์ firebase_options.dart และ google-services.json / GoogleService-Info.plist)',
          ),
          _StepCard(
            step: '3',
            text: 'รันแอปใหม่อีกครั้ง — แอปจะเข้าสู่หน้าเลือกบทบาทโดยอัตโนมัติ',
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.text});
  final String step;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.sosRed,
              foregroundColor: Colors.white,
              child: Text(step),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 16, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}
