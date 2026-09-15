import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/disaster_options.dart';
import 'device_board_page.dart';
import 'emergency_map_page.dart';
import 'log_feed_page.dart';
import 'report_detail_page.dart';
import 'request_keypad_page.dart';
import 'settings_page.dart';

class MtDashboardPage extends StatefulWidget {
  const MtDashboardPage({super.key});

  @override
  State<MtDashboardPage> createState() => _MtDashboardPageState();
}

class _MtDashboardPageState extends State<MtDashboardPage> {
  late final DatabaseReference _emergenciesRef;
  bool _configMissing = false;
  int _selectedTab = 0;

  // ===================== TIMER 5 MENIT =====================
  final Map<String, Timer> _pendingTimers = {};
  final Map<String, Map<String, dynamic>> _pendingAlerts = {};
  final Map<String, bool> _sentFlags = {};

  @override
  void initState() {
    super.initState();
    if (kFirebaseDatabaseUrl == "ISI_URL_REALTIME_DATABASE_DI_SINI" || kFirebaseDatabaseUrl.isEmpty) {
      _configMissing = true;
    } else {
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: kFirebaseDatabaseUrl,
      );
      _emergenciesRef = db.ref('emergencies');
    }
  }

  @override
  void dispose() {
    for (var timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
    super.dispose();
  }

  Future<void> _requestLocationUpdate(String utId) async {
    if (_configMissing) return;
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kFirebaseDatabaseUrl,
    );
    await db.ref('commands/$utId').set({
      'requestLocation': true,
      'requestedAt': ServerValue.timestamp,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permintaan koordinat dikirim ke $utId')),
      );
    }
  }

  // ===================== GENERATE PESAN LAPORAN =====================
  String _generateReportMessage({
    required String areaId,
    required String disaster,
    required String destruction,
    int? subFieldId,
    required double lat,
    required double lon,
    required String time,
  }) {
    final subFieldLine = subFieldId != null ? '\nSub-Field         : #$subFieldId' : '';
    return '''
LAPORAN DARURAT BENCANA - SIGAP SYSTEM
================================================

INFORMASI KEJADIAN:
-----------------------------------------------
Area ID           : $areaId
Jenis Bencana     : $disaster
Tingkat Kerusakan : $destruction$subFieldLine
Waktu Kejadian    : $time

LOKASI:
-----------------------------------------------
Latitude  : ${lat.toStringAsFixed(6)}
Longitude : ${lon.toStringAsFixed(6)}
Link Peta : https://www.google.com/maps?q=${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}

STATUS LAPORAN:
-----------------------------------------------
Status : VALID (dikonfirmasi sistem setelah 5 menit)
Sumber : Field Device Area $areaId

TINDAKAN YANG DISARANKAN:
-----------------------------------------------
- Koordinasi tim evakuasi ke lokasi
- Siapkan logistik dasar untuk pengungsi

--
Dikirim oleh SIGAP Emergency Communication System
''';
  }

  // ===================== KIRIM WHATSAPP =====================
  Future<void> _sendWhatsApp(String phoneNumber, String message) async {
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62' + cleanPhone.substring(1);
    }
    if (!cleanPhone.startsWith('62')) {
      cleanPhone = '62' + cleanPhone;
    }
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/$cleanPhone?text=$encodedMessage';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Gagal buka WhatsApp untuk $phoneNumber');
    }
  }

  // ===================== NOMOR NOTIFIKASI (dari Firebase, bukan hardcode) =====================
  Future<List<String>> _fetchNotifyNumbers() async {
    try {
      final snap = await FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: kFirebaseDatabaseUrl)
          .ref('settings/notifyNumbers')
          .get();
      final raw = snap.value;
      if (raw == null) return [];
      final map = Map<dynamic, dynamic>.from(raw as Map);
      return map.values.map((v) => v.toString()).toList();
    } catch (e) {
      debugPrint('Gagal membaca /settings/notifyNumbers: $e');
      return [];
    }
  }

  void _startEmergencyTimer(String key, Map<String, dynamic> data) {
    if (_pendingTimers.containsKey(key)) return;

    final utId = data['utId']?.toString() ?? 'Tidak diketahui';
    final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
    final lon = (data['lon'] as num?)?.toDouble() ?? 0.0;
    final disasterCode = data['disasterCode'] ?? 0;
    final destructionCode = data['destructionCode'] ?? 0;
    final subFieldId = data['subFieldId'] as int?;
    final ts = data['timestamp'] as int?;

    _pendingAlerts[key] = {
      'utId': utId,
      'lat': lat,
      'lon': lon,
      'disasterCode': disasterCode,
      'destructionCode': destructionCode,
      'subFieldId': subFieldId,
      'timestamp': ts,
    };

    Duration remaining = const Duration(minutes: 5);
    if (ts != null) {
      final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts * 1000));
      remaining = const Duration(minutes: 5) - elapsed;
      if (remaining.isNegative) remaining = Duration.zero;
    }

    final timer = Timer(remaining, () async {
      if (_pendingAlerts.containsKey(key) && !(_sentFlags[key] ?? false)) {
        await _processAndSendReport(key);
      }
    });

    _pendingTimers[key] = timer;
    debugPrint('⏱ Timer dimulai untuk laporan $key (sisa ${remaining.inSeconds}s)');
  }

  Future<void> _processAndSendReport(String key) async {
    final alert = _pendingAlerts.remove(key);
    _pendingTimers.remove(key);

    if (alert == null) return;

    bool claimed = false;
    try {
      final result = await _emergenciesRef.child(key).child('status').runTransaction((current) {
        if (current == null || current == 'baru') {
          return Transaction.success('mengirim');
        }
        return Transaction.abort();
      });
      claimed = result.committed;
    } catch (e) {
      debugPrint('Gagal klaim laporan $key: $e');
    }

    if (!claimed) {
      debugPrint('Laporan $key sudah diklaim/diproses oleh sesi lain, lewati pengiriman WA.');
      _sentFlags[key] = true;
      return;
    }

    final utId = alert['utId'] ?? 'Tidak diketahui';
    final lat = alert['lat'] ?? 0.0;
    final lon = alert['lon'] ?? 0.0;
    final disasterCode = alert['disasterCode'] ?? 0;
    final destructionCode = alert['destructionCode'] ?? 0;
    final subFieldId = alert['subFieldId'] as int?;
    final ts = alert['timestamp'] as int?;

    final disasterName = disasterNameFromCode(disasterCode);
    final destructionName = destructionNameFromCode(destructionCode);
    final timeLabel = ts != null
        ? DateTime.fromMillisecondsSinceEpoch(ts * 1000).toString().substring(0, 16)
        : DateTime.now().toString().substring(0, 16);

    final message = _generateReportMessage(
      areaId: utId,
      disaster: disasterName,
      destruction: destructionName,
      subFieldId: subFieldId,
      lat: lat,
      lon: lon,
      time: timeLabel,
    );

    final numbers = await _fetchNotifyNumbers();
    if (numbers.isEmpty) {
      debugPrint('Tidak ada nomor terdaftar di /settings/notifyNumbers — laporan $key tidak dikirim ke siapa pun.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Tidak ada nomor WhatsApp terdaftar — buka tab Pengaturan'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    for (final number in numbers) {
      await _sendWhatsApp(number, message);
      await Future.delayed(const Duration(seconds: 1));
    }

    _sentFlags[key] = true;

    try {
      await _emergenciesRef.child(key).update({
        'sentToBPBD': true,
        'sentAt': ServerValue.timestamp,
        'status': 'terkirim',
        'sentToNumbers': numbers,
      });
    } catch (e) {
      debugPrint('Gagal update Firebase: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Laporan terkirim ke ${numbers.length} kontak BPBD'),
          backgroundColor: Colors.green,
        ),
      );
    }

    debugPrint('📤 Laporan $key terkirim ke WhatsApp');
  }

  // ===================== BATALKAN TIMER =====================
  Future<void> _cancelPendingAlert(String key) async {
    _pendingTimers[key]?.cancel();
    _pendingTimers.remove(key);
    _pendingAlerts.remove(key);
    _sentFlags[key] = true;
    debugPrint('❌ Timer dibatalkan untuk laporan $key');
    try {
      await _emergenciesRef.child(key).update({'status': 'dibatalkan'});
    } catch (e) {
      debugPrint('Gagal update status dibatalkan untuk $key: $e');
    }
  }

  // ===================== HAPUS SATU LAPORAN =====================
  void _cleanupKeyState(String key) {
    _pendingTimers[key]?.cancel();
    _pendingTimers.remove(key);
    _pendingAlerts.remove(key);
    _sentFlags.remove(key);
  }

  Future<void> _deleteSingleReport(String key, String utId) async {
    _cleanupKeyState(key);
    try {
      await _emergenciesRef.child(key).remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🗑 Laporan $utId dihapus')),
        );
      }
    } catch (e) {
      debugPrint('Gagal hapus laporan $key: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus laporan')),
        );
      }
    }
  }

  Future<void> _confirmDeleteSingle(String key, String utId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Laporan?'),
        content: Text('Laporan "$utId" akan dihapus permanen dan tidak bisa dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteSingleReport(key, utId);
    }
  }

  // ===================== HAPUS SEMUA LAPORAN =====================
  Future<void> _clearAllReports() async {
    for (var timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
    _pendingAlerts.clear();
    _sentFlags.clear();

    try {
      final snap = await _emergenciesRef.get();
      if (snap.exists && snap.value != null) {
        final map = Map<dynamic, dynamic>.from(snap.value as Map);
        final updates = <String, dynamic>{
          for (final key in map.keys) key.toString(): null,
        };
        await _emergenciesRef.update(updates);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑 Semua laporan sudah dihapus')),
        );
      }
    } catch (e) {
      debugPrint('Gagal hapus semua laporan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus semua laporan')),
        );
      }
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Riwayat?'),
        content: const Text(
          'Semua laporan darurat di dashboard ini akan dihapus permanen dan tidak bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _clearAllReports();
    }
  }

  Future<void> _confirmClearAllLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Log?'),
        content: const Text(
          'Semua riwayat aktivitas (HELP, ACK, HEARTBEAT, dll) akan dihapus permanen dan tidak bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: kFirebaseDatabaseUrl).ref('logs').remove();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑 Semua log sudah dihapus')),
          );
        }
      } catch (e) {
        debugPrint('Gagal hapus semua log: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menghapus semua log')),
          );
        }
      }
    }
  }

  // ===================================================================
  // BUILD UI
  // ===================================================================
  @override
  Widget build(BuildContext context) {
    if (_configMissing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard MT')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber, size: 48, color: Colors.orange[700]),
              const SizedBox(height: 16),
              const Text(
                'URL Realtime Database belum diisi.\n'
                    'Buka lib/config.dart, isi konstanta kFirebaseDatabaseUrl\n'
                    'dengan URL dari Firebase Console.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final tabs = <Widget>[
      _buildEmergencyList(),
      const DeviceBoardPage(),
      const LogFeedPage(),
      const RequestKeypadPage(),
      const SettingsPage(),
    ];
    const titles = ['Dashboard MT', 'Status Perangkat', 'Log Aktivitas', 'Minta Data', 'Pengaturan'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedTab]),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedTab == 0)
            IconButton(
              tooltip: 'Hapus Semua Riwayat',
              icon: const Icon(Icons.delete_sweep),
              onPressed: _confirmClearAll,
            ),
          if (_selectedTab == 2)
            IconButton(
              tooltip: 'Hapus Semua Log',
              icon: const Icon(Icons.delete_sweep),
              onPressed: _confirmClearAllLogs,
            ),
        ],
      ),
      body: IndexedStack(index: _selectedTab, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Laporan'),
          NavigationDestination(icon: Icon(Icons.developer_board), label: 'Perangkat'),
          NavigationDestination(icon: Icon(Icons.article_outlined), label: 'Log'),
          NavigationDestination(icon: Icon(Icons.dialpad), label: 'Keypad'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Pengaturan'),
        ],
      ),
    );
  }

  Widget _buildEmergencyList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _emergenciesRef.orderByChild('timestamp').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final raw = snapshot.data?.snapshot.value;
        if (raw == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Belum ada laporan darurat masuk.', textAlign: TextAlign.center),
            ),
          );
        }

        final Map<dynamic, dynamic> map = raw as Map<dynamic, dynamic>;
        final entries = map.entries.toList()
          ..sort((a, b) {
            final ta = (a.value as Map)['timestamp'] ?? 0;
            final tb = (b.value as Map)['timestamp'] ?? 0;
            return (tb as num).compareTo(ta as num);
          });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final key = entries[index].key.toString();
            final data = Map<String, dynamic>.from(entries[index].value as Map);

            final utId = data['utId']?.toString() ?? 'Tidak diketahui';
            final lat = (data['lat'] as num?)?.toDouble();
            final lon = (data['lon'] as num?)?.toDouble();
            final disasterName = disasterNameFromCode(data['disasterCode']);
            final destructionName = destructionNameFromCode(data['destructionCode']);
            final status = data['status']?.toString() ?? 'baru';
            final ts = data['timestamp'] as int?;
            final timeLabel = ts != null
                ? DateTime.fromMillisecondsSinceEpoch(ts * 1000).toString().substring(0, 16)
                : '-';
            final subFieldId = data['subFieldId'] as int?;
            final sentToBPBD = data['sentToBPBD'] == true;
            final sentToNumbersRaw = data['sentToNumbers'];
            final sentToNumbersCount = sentToNumbersRaw is List ? sentToNumbersRaw.length : 0;

            // ===== CEK LAPORAN BARU =====
            if (status == 'baru' && !_pendingTimers.containsKey(key) && !sentToBPBD) {
              _startEmergencyTimer(key, data);
            }

            // ===== CEK JIKA LAPORAN SUDAH TERKIRIM =====
            if (sentToBPBD && _pendingTimers.containsKey(key)) {
              _pendingTimers[key]?.cancel();
              _pendingTimers.remove(key);
              _pendingAlerts.remove(key);
            }

            // Hentikan timer jika sudah ditangani/selesai/dibatalkan
            if ((status == 'ditangani' || status == 'selesai' || status == 'dibatalkan') &&
                _pendingTimers.containsKey(key)) {
              _pendingTimers[key]?.cancel();
              _pendingTimers.remove(key);
              _pendingAlerts.remove(key);
            }

            Color statusColor;
            String statusLabel;
            if (sentToBPBD) {
              statusColor = Colors.green[600]!;
              statusLabel = 'Terkirim ke BPBD ✅';
            } else if (status == 'mengirim') {
              statusColor = Colors.blue[600]!;
              statusLabel = 'Mengirim ke BPBD...';
            } else if (status == 'ditangani') {
              statusColor = Colors.orange[700]!;
              statusLabel = 'Ditangani';
            } else if (status == 'selesai') {
              statusColor = Colors.green[600]!;
              statusLabel = 'Selesai';
            } else if (status == 'dibatalkan') {
              statusColor = Colors.grey[500]!;
              statusLabel = 'Dibatalkan';
            } else {
              statusColor = Colors.red[600]!;
              statusLabel = 'Menunggu Validasi (5 menit) ⏱';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Icon(Icons.warning_amber, color: statusColor),
                ),
                title: Text('$disasterName · $utId', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Kerusakan: $destructionName'),
                    if (subFieldId != null) Text('Sub-Field: #$subFieldId'),
                    Text('Status: $statusLabel', style: TextStyle(color: statusColor, fontWeight: FontWeight.w500)),
                    Text('Waktu: $timeLabel', style: const TextStyle(fontSize: 12)),
                    if (lat != null && lon != null)
                      Text('${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    if (sentToBPBD)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.chat, size: 14, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              sentToNumbersCount > 0
                                  ? 'Terkirim ke $sentToNumbersCount kontak BPBD'
                                  : 'Terkirim ke BPBD (jumlah kontak tidak tercatat)',
                              style: TextStyle(fontSize: 11, color: Colors.green[700]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'map' && lat != null && lon != null) {
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
                    } else if (value == 'request') {
                      _requestLocationUpdate(utId);
                    } else if (value == 'cancel') {
                      _cancelPendingAlert(key);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('⏹ Timer dibatalkan untuk laporan $utId')),
                      );
                    } else if (value == 'sendNow') {
                      _processAndSendReport(key);
                    } else if (value == 'delete') {
                      _confirmDeleteSingle(key, utId);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'map',
                      child: Row(children: [Icon(Icons.map, size: 18), SizedBox(width: 8), Text('Lihat di Peta')]),
                    ),
                    const PopupMenuItem(
                      value: 'request',
                      child: Row(children: [Icon(Icons.my_location, size: 18), SizedBox(width: 8), Text('Minta Update Koordinat')]),
                    ),
                    if (!sentToBPBD && status != 'dibatalkan')
                      const PopupMenuItem(
                        value: 'sendNow',
                        child: Row(children: [Icon(Icons.send, size: 18, color: Colors.green), SizedBox(width: 8), Text('Kirim Sekarang', style: TextStyle(color: Colors.green))]),
                      ),
                    if (_pendingTimers.containsKey(key))
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Row(children: [Icon(Icons.cancel, size: 18, color: Colors.red), SizedBox(width: 8), Text('Batalkan Timer', style: TextStyle(color: Colors.red))]),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Hapus Pesan', style: TextStyle(color: Colors.red))]),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ReportDetailPage(reportId: key, data: data),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}