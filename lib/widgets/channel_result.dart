import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Delivery summary per channel (FCM / LINE / SMS), fed by Cloud Functions.
class ChannelResult extends StatelessWidget {
  const ChannelResult({super.key, required this.alert});
  final AlertRecord? alert;

  @override
  Widget build(BuildContext context) {
    if (alert == null || alert!.channels.isEmpty) {
      return const Text(
        'กำลังตรวจสอบการส่งแต่ละช่องทาง...',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54),
      );
    }

    final fcm = _num(alert!.channels['fcm']);
    final line = _num(alert!.channels['line']);
    final sms = _num(alert!.channels['sms']);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('แอป (Push)', fcm, Icons.smartphone),
        _chip('LINE', line, Icons.chat_bubble),
        _chip('SMS', sms, Icons.sms),
      ],
    );
  }

  int? _num(dynamic v) {
    if (v is Map<String, dynamic>) {
      final sent = v['sent'];
      if (sent is int) return sent;
    }
    return null;
  }

  Widget _chip(String label, int? count, IconData icon) {
    final color = (count ?? 0) > 0 ? AppTheme.okGreen : Colors.black45;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text('$label: ${count != null ? 'ส่งแล้ว $count รายการ' : 'ระหว่างส่ง/ข้าม'}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
