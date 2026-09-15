import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/disaster_options.dart';
import 'emergency_map_page.dart';

class ReportDetailPage extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> data;

  const ReportDetailPage({super.key, required this.reportId, required this.data});

  @override
  Widget build(BuildContext context) {
    final utId = data['utId']?.toString() ?? 'Tidak diketahui';
    final lat = (data['lat'] as num?)?.toDouble();
    final lon = (data['lon'] as num?)?.toDouble();
    final disasterName = disasterNameFromCode(data['disasterCode']);
    final destructionName = destructionNameFromCode(data['destructionCode']);
    final subFieldId = data['subFieldId'] as int?;
    final status = data['status']?.toString() ?? 'baru';
    final sentToBPBD = data['sentToBPBD'] == true;

    final ts = (data['timestamp'] as num?)?.toInt();
    final timeLabel = ts != null
        ? DateTime.fromMillisecondsSinceEpoch(ts * 1000).toString().substring(0, 19)
        : '-';

    // sentAt is written via ServerValue.timestamp (Dart/Flutter side), which
    // is already real milliseconds — unlike `timestamp` above, which comes
    // from hq.txt's time(nullptr) in seconds. Don't multiply this one.
    final sentAtMs = (data['sentAt'] as num?)?.toInt();
    final sentAtLabel = sentAtMs != null
        ? DateTime.fromMillisecondsSinceEpoch(sentAtMs).toString().substring(0, 19)
        : null;

    final sentToNumbersRaw = data['sentToNumbers'];
    final sentToNumbers = sentToNumbersRaw is List
        ? sentToNumbersRaw.map((e) => e.toString()).toList()
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Laporan · $utId'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Color(0xFFE53935)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('$disasterName · $utId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _row('Kerusakan', destructionName),
                  if (subFieldId != null) _row('Sub-Field', '#$subFieldId'),
                  _row('Status', _statusLabel(status, sentToBPBD)),
                  _row('Waktu kejadian', timeLabel),
                  if (lat != null && lon != null)
                    _row('Koordinat', '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (lat != null && lon != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EmergencyMapPage(
                        position: ll.LatLng(lat, lon),
                        title: 'Lokasi $utId',
                        disasterName: disasterName,
                        destructionName: destructionName,
                        sentAt: ts != null ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : null,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Buka Peta'),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.send_outlined, color: Colors.grey[700], size: 20),
                      const SizedBox(width: 8),
                      const Text('Dikirim Kepada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!sentToBPBD)
                    Text(
                      status == 'dibatalkan'
                          ? 'Laporan dibatalkan sebelum terkirim — tidak ada yang dihubungi.'
                          : 'Belum terkirim — menunggu validasi (5 menit) atau proses pengiriman.',
                      style: TextStyle(color: Colors.grey[600]),
                    )
                  else if (sentToNumbers.isEmpty)
                    Text(
                      'Laporan ini ditandai terkirim, tapi tidak ada catatan nomor penerima '
                          '(kemungkinan dikirim sebelum fitur pencatatan ini ditambahkan).',
                      style: TextStyle(color: Colors.orange[800]),
                    )
                  else
                    ...sentToNumbers.map((n) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Color(0xFF25D366)),
                          const SizedBox(width: 8),
                          Text('+$n', style: const TextStyle(fontFamily: 'monospace')),
                        ],
                      ),
                    )),
                  if (sentAtLabel != null) ...[
                    const SizedBox(height: 6),
                    Text('Dikirim pada: $sentAtLabel', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _statusLabel(String status, bool sentToBPBD) {
    if (sentToBPBD) return 'Terkirim ke BPBD ✅';
    switch (status) {
      case 'mengirim': return 'Mengirim ke BPBD...';
      case 'ditangani': return 'Ditangani';
      case 'selesai': return 'Selesai';
      case 'dibatalkan': return 'Dibatalkan';
      default: return 'Menunggu Validasi (5 menit) ⏱';
    }
  }
}