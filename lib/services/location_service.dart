import 'package:geolocator/geolocator.dart';

/// Backs the "ระบบระบุตำแหน่ง" requirement (1.4.1.4 Google Maps API,
/// 2.5.4) — used to find jobs near the user and show distance,
/// and to let an employer pin the job location when posting.
class LocationService {
  /// Requests permission (if needed) and returns the current device
  /// position. Throws a [StateError] with a Thai message the UI can
  /// show directly if location services/permission aren't available.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('กรุณาเปิดบริการตำแหน่ง (Location Services)');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw StateError('แอปไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
          'สิทธิ์การเข้าถึงตำแหน่งถูกปฏิเสธถาวร กรุณาเปิดในตั้งค่าเครื่อง');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Distance between two coordinates, in kilometers.
  double distanceKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final meters = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    return meters / 1000;
  }

  /// Thai-friendly distance label for job cards, e.g. "1.2 กม." or
  /// "350 ม." for anything under a kilometer.
  String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} ม.';
    return '${km.toStringAsFixed(1)} กม.';
  }
}
