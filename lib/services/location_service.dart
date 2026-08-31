import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GpsPosition {
  const GpsPosition({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

/// Best-effort current position for SOS alerts.
///
/// Returns null quickly when permission is denied or GPS is unavailable —
/// an SOS must never be blocked on location.
Future<GpsPosition?> getCurrentPosition({Duration timeout = const Duration(seconds: 8)}) async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeout,
      ),
    );
    return GpsPosition(lat: position.latitude, lng: position.longitude);
  } catch (e) {
    debugPrint('[location] failed: $e');
    return null;
  }
}
