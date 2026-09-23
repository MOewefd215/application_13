import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';

/// Center-pin map picker for "หน้าโพสต์งาน" (3.3.5) — lets the employer
/// choose job_lat / job_lng by moving the map under a fixed marker,
/// then returns the picked LatLng via Navigator.pop.
///
/// Uses OpenStreetMap tiles via flutter_map — free, no API key or
/// billing account required.
class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _locationService = LocationService();
  final _mapController = MapController();
  LatLng _center = const LatLng(13.7563, 100.5018); // Bangkok, ค่าเริ่มต้น
  bool _loadingCurrentLocation = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
      _loadingCurrentLocation = false;
    } else {
      _useCurrentLocation();
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingCurrentLocation = true);
    try {
      final position = await _locationService.getCurrentPosition();
      final newCenter = LatLng(position.latitude, position.longitude);
      setState(() => _center = newCenter);
      _mapController.move(newCenter, 15);
    } catch (_) {
      // เงียบไว้ — ผู้ใช้ยังเลื่อนแผนที่เลือกตำแหน่งเองได้
    } finally {
      if (mounted) setState(() => _loadingCurrentLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เลือกสถานที่ทำงาน')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onPositionChanged: (position, hasGesture) {
                _center = position.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.studentpro_ui',
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          const IgnorePointer(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(Icons.location_on, size: 44, color: AppColors.navy),
            ),
          ),
          if (_loadingCurrentLocation)
            const Positioned(
              top: 16,
              child: Chip(label: Text('กำลังค้นหาตำแหน่งปัจจุบัน...')),
            ),
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.card,
              onPressed: _useCurrentLocation,
              child: const Icon(Icons.my_location, color: AppColors.navy),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _center),
              child: const Text('ยืนยันตำแหน่งนี้'),
            ),
          ),
        ],
      ),
    );
  }
}
