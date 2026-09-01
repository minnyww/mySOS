import 'package:cloud_firestore/cloud_firestore.dart';

import 'config.dart';

enum Role { user, caregiver }

Role? roleFromString(String? s) =>
    s == 'user' ? Role.user : s == 'caregiver' ? Role.caregiver : null;

extension RoleLabel on Role {
  String get label => this == Role.user ? 'ผู้ใช้' : 'ผู้ดูแล';
}

class Profile {
  const Profile({
    required this.uid,
    this.role,
    this.displayName,
    this.phone,
    this.fcmTokens = const [],
    this.lineUserId,
    this.caregiverUids = const [],
    this.caringUids = const [],
    this.lineLinkCode,
    this.lineLinkExpiresAt,
  });

  final String uid;
  final Role? role;
  final String? displayName;
  final String? phone;
  final List<String> fcmTokens;
  final String? lineUserId;
  final List<String> caregiverUids;
  final List<String> caringUids;
  final String? lineLinkCode;
  final int? lineLinkExpiresAt;

  bool get isLineLinked => lineUserId != null && lineUserId!.isNotEmpty;

  static Profile fromDoc(String uid, Map<String, dynamic>? data) {
    return Profile(
      uid: uid,
      role: roleFromString(data?['role'] as String?),
      displayName: data?['displayName'] as String?,
      phone: data?['phone'] as String?,
      fcmTokens: (data?['fcmTokens'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      lineUserId: data?['lineUserId'] as String?,
      caregiverUids: (data?['caregiverUids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      caringUids: (data?['caringUids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      lineLinkCode: data?['lineLinkCode'] as String?,
      lineLinkExpiresAt: data?['lineLinkExpiresAt'] as int?,
    );
  }
}

/// One point of the live-location trail written while an SOS is active.
class TrailPoint {
  const TrailPoint({required this.lat, required this.lng, required this.ts});
  final double lat;
  final double lng;
  final int ts;

  static TrailPoint? fromData(Object? o) {
    if (o is! Map<String, dynamic>) return null;
    final lat = o['lat'];
    final lng = o['lng'];
    final ts = o['ts'];
    if (lat is! double || lng is! double || ts is! int) return null;
    return TrailPoint(lat: lat, lng: lng, ts: ts);
  }
}

/// status: active | acked | cancelled | rate_limited | no_caregivers | failed
class AlertRecord {
  const AlertRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.ts,
    required this.status,
    required this.source,
    this.lat,
    this.lng,
    this.ackBy,
    this.ackByName,
    this.ackAt,
    this.locationUpdatedAt,
    this.trail = const [],
    this.caregiverUids = const [],
    this.channels = const {},
  });

  final String id;
  final String userId;
  final String userName;
  final int ts;
  final String status;
  final String source; // app | widget
  final double? lat;
  final double? lng;
  final String? ackBy;
  final String? ackByName;
  final int? ackAt;
  final int? locationUpdatedAt;
  final List<TrailPoint> trail;
  final List<String> caregiverUids;
  final Map<String, dynamic> channels;

  bool get isActive => status == 'active';
  bool get hasLocation => lat != null && lng != null;

  /// End of the 10-minute live-sharing window, in ms since epoch.
  int get liveUntil => ts + AppConfig.liveLocationWindow.inMilliseconds;

  bool get isWithinLiveWindow =>
      DateTime.now().millisecondsSinceEpoch < liveUntil;

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'กำลังรอการตอบรับ';
      case 'acked':
        return 'ผู้ดูแลรับทราบแล้ว';
      case 'cancelled':
        return 'ยกเลิกแล้ว';
      case 'rate_limited':
        return 'ส่งถี่เกินไป (รอ 1 นาที)';
      case 'no_caregivers':
        return 'ยังไม่มีผู้ดูแลเชื่อมต่อ';
      case 'failed':
        return 'ส่งไม่สำเร็จ';
      default:
        return status;
    }
  }

  String mapUrl() => 'https://maps.google.com/?q=$lat,$lng';

  static AlertRecord fromDoc(String id, Map<String, dynamic> data) {
    final loc = data['location'] as Map<String, dynamic>?;
    final channels =
        data['channels'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return AlertRecord(
      id: id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      ts: data['ts'] as int? ?? 0,
      status: data['status'] as String? ?? 'active',
      source: data['source'] as String? ?? 'app',
      lat: loc?['lat'] as double?,
      lng: loc?['lng'] as double?,
      ackBy: data['ackBy'] as String?,
      ackByName: data['ackByName'] as String?,
      ackAt: data['ackAt'] as int?,
      locationUpdatedAt: data['locationUpdatedAt'] as int?,
      trail: (data['locationHistory'] as List<dynamic>? ?? const [])
          .map(TrailPoint.fromData)
          .whereType<TrailPoint>()
          .toList(),
      caregiverUids: (data['caregiverUids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      channels: channels,
    );
  }

  factory AlertRecord.fromSnapshot(DocumentSnapshot doc) =>
      AlertRecord.fromDoc(doc.id, doc.data() as Map<String, dynamic>? ?? {});
}
