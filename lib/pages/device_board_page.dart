import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../utils/time_utils.dart';

// Same threshold hq.txt uses to decide a device has gone stale
// (HEARTBEAT_TIMEOUT), kept here for a "menghilang tanpa offline-push"
// fallback in case the app was closed when the firmware pushed active:false.
const int _kHeartbeatTimeoutMs = 2100000;

class DeviceBoardPage extends StatelessWidget {
  const DeviceBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: kFirebaseDatabaseUrl);
    final devicesRef = db.ref('devices');

    return StreamBuilder<DatabaseEvent>(
      stream: devicesRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final raw = snapshot.data?.snapshot.value;
        if (raw == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Belum ada perangkat yang tercatat.', textAlign: TextAlign.center),
            ),
          );
        }

        final Map<dynamic, dynamic> map = raw as Map<dynamic, dynamic>;
        final entries = map.entries.toList()
          ..sort((a, b) => (a.value['areaId'] as num).compareTo(b.value['areaId'] as num));

        final activeCount = entries.where((e) => _isOnline(Map<String, dynamic>.from(e.value))).length;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.green[50],
              child: Text(
                '$activeCount dari ${entries.length} area aktif',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green[800]),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final data = Map<String, dynamic>.from(entries[index].value);
                  final areaId = data['areaId'];
                  final deviceType = data['deviceType'] ?? 0;
                  final online = _isOnline(data);
                  final lastSeen = data['lastSeen'] as int?;

                  final typeLabel = deviceType == 0 ? 'UT' : 'RN';
                  final color = online
                      ? (deviceType == 0 ? const Color(0xFF0480C0) : const Color(0xFF001FA0))
                      : Colors.grey[400]!;

                  return Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      border: Border.all(color: color, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(online ? Icons.circle : Icons.circle_outlined, size: 10, color: color),
                            const SizedBox(width: 6),
                            Text('Area $areaId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(typeLabel, style: TextStyle(fontSize: 12, color: color)),
                        if (lastSeen != null)
                          Text(
                            online ? 'Online' : _agoLabel(lastSeen),
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isOnline(Map<String, dynamic> data) {
    if (data['active'] != true) return false;
    final lastSeen = data['lastSeen'] as int?;
    if (lastSeen == null) return true;
    final lastSeenMs = parseFirebaseTimestamp(lastSeen).millisecondsSinceEpoch;
    final ageMs = DateTime.now().millisecondsSinceEpoch - lastSeenMs;
    return ageMs < _kHeartbeatTimeoutMs;
  }

  String _agoLabel(int lastSeenEpoch) {
    final dt = parseFirebaseTimestamp(lastSeenEpoch);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}