import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Small colored chip showing an alert status in Thai.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.alert});
  final AlertRecord alert;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (alert.status) {
      'acked' => (AppTheme.okGreen, Icons.check_circle),
      'active' => (AppTheme.sosRed, Icons.notifications_active),
      'rate_limited' => (Colors.orange, Icons.timer),
      'no_caregivers' => (Colors.orange, Icons.person_off),
      'failed' => (Colors.redAccent, Icons.error_outline),
      _ => (Colors.grey, Icons.cancel_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(alert.statusLabel,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
