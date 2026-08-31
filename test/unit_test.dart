import 'package:flutter_test/flutter_test.dart';
import 'package:mysos/models.dart';
import 'package:mysos/services/pairing_service.dart';
import 'package:mysos/widgets/status_chip.dart';
import 'package:flutter/material.dart';

void main() {
  group('PairingService.parseQrPayload', () {
    test('parses a mysos deep link', () {
      expect(PairingService.parseQrPayload('mysos://pair/123456'), '123456');
    });

    test('parses an https deep link', () {
      expect(
        PairingService.parseQrPayload('https://mysos.app/pair/987654?x=1'),
        '987654',
      );
    });

    test('rejects unrelated payloads', () {
      expect(PairingService.parseQrPayload('https://example.com/hello'), isNull);
      expect(PairingService.parseQrPayload('mysos://pair/12ab'), isNull);
      expect(PairingService.parseQrPayload(''), isNull);
    });

    test('builds the QR deep link', () {
      expect(PairingService.qrPayload('123456'), 'mysos://pair/123456');
    });
  });

  group('AlertRecord', () {
    final data = {
      'userId': 'u1',
      'userName': 'คุณแม่',
      'ts': 1735689600000,
      'status': 'acked',
      'source': 'widget',
      'caregiverUids': ['c1', 'c2'],
      'location': {'lat': 13.75, 'lng': 100.5},
      'ackByName': 'ลูกสาว',
      'channels': {
        'fcm': {'sent': 2, 'failed': 0},
        'line': {'sent': 1},
        'sms': {'skipped': 'not-configured'},
      },
    };

    test('parses document data', () {
      final a = AlertRecord.fromDoc('a1', data);
      expect(a.id, 'a1');
      expect(a.userName, 'คุณแม่');
      expect(a.statusLabel, 'ผู้ดูแลรับทราบแล้ว');
      expect(a.lat, 13.75);
      expect(a.lng, 100.5);
      expect(a.hasLocation, isTrue);
      expect(a.caregiverUids, ['c1', 'c2']);
      expect(a.channels['fcm'], isA<Map<String, dynamic>>());
    });

    test('map url points to google maps', () {
      final a = AlertRecord.fromDoc('a1', data);
      expect(a.mapUrl(), 'https://maps.google.com/?q=13.75,100.5');
    });

    test('status labels cover every server state', () {
      for (final status in [
        'active', 'acked', 'cancelled', 'rate_limited', 'no_caregivers', 'failed'
      ]) {
        final a = AlertRecord.fromDoc('a', {...data, 'status': status});
        expect(a.statusLabel, isNotEmpty);
        expect(a.statusLabel, isNot(equals(status)));
      }
    });
  });

  group('StatusChip', () {
    testWidgets('renders the Thai status label', (tester) async {
      const alert = AlertRecord(
        id: 'a1',
        userId: 'u1',
        userName: 'คุณแม่',
        ts: 0,
        status: 'active',
        source: 'app',
      );
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StatusChip(alert: alert))));
      expect(find.text('กำลังรอการตอบรับ'), findsOneWidget);
    });
  });
}
