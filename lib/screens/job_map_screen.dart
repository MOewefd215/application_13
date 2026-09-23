import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';

/// Shows where a job is located, plus the distance from the user's
/// current position — the "ระบบแสดงตำแหน่งงานบนแผนที่" piece described
/// in Context Diagram (รูปที่ 3.2.2).
///
/// Uses OpenStreetMap tiles via flutter_map — no API key, no billing
/// account, no credit card required (unlike Google Maps Platform,
/// which requires billing to be enabled even for free-tier usage).
class JobMapScreen extends StatefulWidget {
  final String jobTitle;
  final double? jobLat;
  final double? jobLng;

  const JobMapScreen({
    super.key,
    required this.jobTitle,
    this.jobLat,
    this.jobLng,
  });

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  final _locationService = LocationService();
  String? _distanceLabel;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadDistance();
  }

  Future<void> _loadDistance() async {
    if (widget.jobLat == null || widget.jobLng == null) return;
    try {
      final position = await _locationService.getCurrentPosition();
      final km = _locationService.distanceKm(
        lat1: position.latitude,
        lng1: position.longitude,
        lat2: widget.jobLat!,
        lng2: widget.jobLng!,
      );
      if (mounted) {
        setState(() => _distanceLabel = _locationService.formatDistance(km));
      }
    } catch (e) {
      if (mounted) setState(() => _errorText = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = widget.jobLat != null && widget.jobLng != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.jobTitle)),
      body: hasCoords
          ? Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(widget.jobLat!, widget.jobLng!),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.studentpro_ui',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(widget.jobLat!, widget.jobLng!),
                          width: 44,
                          height: 44,
                          child: const Icon(Icons.location_on,
                              color: AppColors.navy, size: 44),
                        ),
                      ],
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                if (_distanceLabel != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.social_distance,
                              size: 18, color: AppColors.navy),
                          const SizedBox(width: 8),
                          Text('ห่างจากคุณประมาณ $_distanceLabel'),
                        ],
                      ),
                    ),
                  ),
                if (_errorText != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: Text(_errorText!,
                          style: const TextStyle(color: AppColors.danger)),
                    ),
                  ),
              ],
            )
          : const EmptyState(
              icon: Icons.location_off_outlined,
              message: 'งานนี้ยังไม่ได้ระบุตำแหน่งบนแผนที่',
            ),
    );
  }
}
