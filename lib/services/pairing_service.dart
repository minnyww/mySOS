import 'db.dart';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';

class PairCodeException implements Exception {
  const PairCodeException(this.message);
  final String message;

  static PairCodeException fromError(Object e) {
    final s = e.toString();
    if (s.contains('permission-denied') || s.contains('PERMISSION_DENIED')) {
      // Firestore rules reject: expired code, already claimed, or wrong state.
      return const PairCodeException(
          'รหัสไม่ถูกต้อง ถูกใช้ไปแล้ว หรือหมดอายุ (อายุ 10 นาที) กรุณาขอรหัสใหม่');
    }
    return PairCodeException('เกิดข้อผิดพลาด: ${s.split(']').last.trim()}');
  }

  @override
  String toString() => message;
}

/// Pair-code lifecycle: generation (user side) and claiming (caregiver side).
class PairingService {
  PairingService({FirebaseFirestore? firestore})
      : _db = firestore ?? mysosDb;

  final FirebaseFirestore _db;
  final Random _random = Random();

  CollectionReference<Map<String, dynamic>> get _pairs =>
      _db.collection('pairs');

  /// Generate a fresh 6-digit code owned by [uid], valid for [AppConfig.pairCodeTtl].
  Future<String> createPairCode(String uid) async {
    String code = _generateCode();
    // Retry on the rare collision with an existing pending code.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _pairs.doc(code).set({
          'ownerUid': uid,
          'role': 'user',
          'status': 'pending',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'expiresAt': DateTime.now()
              .add(AppConfig.pairCodeTtl)
              .millisecondsSinceEpoch,
        });
        return code;
      } on FirebaseException catch (e) {
        if (e.code == 'already-exists' || e.code == 'permission-denied') {
          code = _generateCode();
          continue;
        }
        rethrow;
      }
    }
    throw const PairCodeException('สร้างรหัสไม่สำเร็จ กรุณาลองใหม่');
  }

  String _generateCode() {
    // 6 digits, first digit 1-9 to keep it a plain 6-digit number.
    final first = _random.nextInt(9) + 1;
    final rest = List.generate(5, (_) => _random.nextInt(10)).join();
    return '$first$rest';
  }

  /// QR payload: a deep link the caregiver app understands.
  static String qrPayload(String code) =>
      '${AppConfig.deepLinkScheme}://pair/$code';

  /// Extract a pair code from a scanned QR string, null if unrelated.
  static String? parseQrPayload(String raw) {
    final match = RegExp(r'pair/(\d{6})').firstMatch(raw);
    return match?.group(1);
  }

  /// Caregiver claims a code. Throws [PairCodeException] on any failure.
  Future<void> acceptPairCode(String code, String caregiverUid) async {
    try {
      await _pairs.doc(code).update({'acceptedBy': caregiverUid});
    } catch (e) {
      throw PairCodeException.fromError(e);
    }
  }

  /// Live state of a pair document — 'pending' | 'linked' | missing.
  Stream<String> watchPairStatus(String code) {
    return _pairs.doc(code).snapshots().map((snap) {
      if (!snap.exists) return 'missing';
      return snap.data()?['status'] as String? ?? 'pending';
    });
  }

  Future<void> cancelPairCode(String code, String ownerUid) async {
    try {
      await _pairs.doc(code).delete();
    } catch (_) {
      // Expired codes may already be gone; deletion is best-effort.
    }
  }

  /// Generate a LINE linking code for [uid] (10-minute validity).
  Future<String> createLineLinkCode(String uid) async {
    final first = _random.nextInt(9) + 1;
    final rest = List.generate(5, (_) => _random.nextInt(10)).join();
    final code = '$first$rest';
    await _db.collection('users').doc(uid).update({
      'lineLinkCode': code,
      'lineLinkExpiresAt':
          DateTime.now().add(AppConfig.pairCodeTtl).millisecondsSinceEpoch,
    });
    return code;
  }
}
