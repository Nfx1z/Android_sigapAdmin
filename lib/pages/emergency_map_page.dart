import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

class EmergencyMapPage extends StatelessWidget {
  final ll.LatLng position;
  final String title;
  final String? disasterName;
  final String? destructionName;
  final DateTime? sentAt;

  const EmergencyMapPage({
    super.key,
    required this.position,
    this.title = 'Lokasi',
    this.disasterName,
    this.destructionName,
    this.sentAt,
  });

  Future<void> _openInGoogleMaps() async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDisasterInfo = disasterName != null && destructionName != null;
    final timeLabel = sentAt != null
        ? '${sentAt!.hour.toString().padLeft(2, '0')}:${sentAt!.minute.toString().padLeft(2, '0')} '
        '${sentAt!.day}/${sentAt!.month}/${sentAt!.year}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(initialCenter: position, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sigap.emergency_comm',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: position,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Color(0xFFE53935), size: 50),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDisasterInfo) ...[
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Color(0xFFE53935)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$disasterName · Kerusakan $destructionName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (timeLabel != null)
                    Text('Dikirim: $timeLabel', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                ],
                Text('${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _openInGoogleMaps,
                  icon: const Icon(Icons.map),
                  label: const Text('Buka di Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}