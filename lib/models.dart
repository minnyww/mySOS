import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<String> caregiverUids;
  final Map<String, dynamic> channels;

  bool get isActive => status == 'active';
  bool get hasLocation => lat != null && lng != null;

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
      caregiverUids: (data['caregiverUids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      channels: channels,
    );
  }

  factory AlertRecord.fromSnapshot(DocumentSnapshot doc) =>
      AlertRecord.fromDoc(doc.id, doc.data() as Map<String, dynamic>? ?? {});
}
