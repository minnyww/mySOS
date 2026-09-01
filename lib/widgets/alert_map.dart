import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../theme.dart';

/// In-app map for an SOS alert: current-position marker, movement trail,
/// and a live-status banner with the remaining sharing window.
class AlertMapCard extends StatefulWidget {
  const AlertMapCard({super.key, required this.alert, this.height = 280});

  final AlertRecord alert;
  final double height;

  @override
  State<AlertMapCard> createState() => _AlertMapCardState();
}

class _AlertMapCardState extends State<AlertMapCard> {
  final MapController _map = MapController();
  LatLng? _followed;

  @override
  void didUpdateWidget(AlertMapCard old) {
    super.didUpdateWidget(old);
    // Keep the moving marker in view as live updates arrive.
    final center = _center;
    if (center != null && center != _followed) {
      _followed = center;
      _map.move(center, _map.camera.zoom.clamp(15.0, 17.0));
    }
  }

  LatLng? get _center {
    final a = widget.alert;
    if (!a.hasLocation) return null;
    return LatLng(a.lat!, a.lng!);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final center = _center ?? const LatLng(13.7563, 100.5018); // Bangkok fallback
    _followed ??= _center;

    final trail = <LatLng>[
      for (final p in a.trail) LatLng(p.lat, p.lng),
      if (a.hasLocation) LatLng(a.lat!, a.lng!),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: widget.height,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(initialCenter: center, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mysos.mysos',
                ),
                if (trail.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: trail,
                        strokeWidth: 4,
                        color: AppTheme.sosRed.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 44,
                      height: 44,
                      child: const _SosMarker(),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          LiveLocationBanner(alert: a),
        ],
      ),
    );
  }
}

class _SosMarker extends StatelessWidget {
  const _SosMarker();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.person_pin_circle,
        size: 44, color: AppTheme.sosRed, shadows: [
          Shadow(color: Colors.white, blurRadius: 4),
        ]);
  }
}

/// Live-sharing status under the map: countdown of the 10-minute window,
/// freshness of the last fix, and the trail length.
class LiveLocationBanner extends StatefulWidget {
  const LiveLocationBanner({super.key, required this.alert});

  final AlertRecord alert;

  @override
  State<LiveLocationBanner> createState() => _LiveLocationBannerState();
}

class _LiveLocationBannerState extends State<LiveLocationBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = a.liveUntil - now;
    final lastUpdate = a.locationUpdatedAt;

    Widget content;
    if (!a.isActive) {
      content = const Row(
        children: [
          Icon(Icons.lock_clock, size: 18, color: Colors.black54),
          SizedBox(width: 6),
          Expanded(
            child: Text('การแชร์ตำแหน่งสิ้นสุดแล้ว (การแจ้งเตือนถูกรับทราบ/ยกเลิก)',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
          ),
        ],
      );
    } else if (remaining <= 0) {
      content = const Row(
        children: [
          Icon(Icons.timer_off, size: 18, color: Colors.black54),
          SizedBox(width: 6),
          Expanded(
            child: Text('การแชร์ตำแหน่งครบ 10 นาทีแล้ว — แสดงตำแหน่งสุดท้าย',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
          ),
        ],
      );
    } else {
      final fresh = lastUpdate != null && now - lastUpdate < 30000;
      final mm = (remaining ~/ 60000).toString().padLeft(2, '0');
      final ss = ((remaining % 60000) ~/ 1000).toString().padLeft(2, '0');
      content = Row(
        children: [
          Icon(
            fresh ? Icons.my_location : Icons.location_searching,
            size: 18,
            color: fresh ? AppTheme.okGreen : Colors.orange,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              fresh
                  ? 'กำลังแชร์ตำแหน่งสด • เหลือ $mm:$ss นาที'
                  : 'ตำแหน่งล่าสุด ${lastUpdate != null ? _clockText(lastUpdate) : '—'} • เหลือ $mm:$ss นาที',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (a.trail.isNotEmpty)
            Text('${a.trail.length} จุด',
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      );
    }

    return Container(
      width: double.infinity,
      color: Colors.black.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: content,
    );
  }

  String _clockText(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}

/// Compact one-line live indicator for the owner's "sent" view.
class LiveShareChip extends StatefulWidget {
  const LiveShareChip({super.key, required this.alert});

  final AlertRecord alert;

  @override
  State<LiveShareChip> createState() => _LiveShareChipState();
}

class _LiveShareChipState extends State<LiveShareChip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final remaining = a.liveUntil - DateTime.now().millisecondsSinceEpoch;
    if (!a.isActive || remaining <= 0 || !a.hasLocation) {
      return const SizedBox.shrink();
    }
    final mm = (remaining ~/ 60000).toString().padLeft(2, '0');
    final ss = ((remaining % 60000) ~/ 1000).toString().padLeft(2, '0');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.my_location, size: 18, color: AppTheme.okGreen),
        const SizedBox(width: 6),
        Text(
          'แชร์ตำแหน่งสดถึงผู้ดูแล • อีก $mm:$ss นาที',
          style: const TextStyle(fontSize: 15, color: Colors.black54),
        ),
      ],
    );
  }
}
