import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models/log_kind.dart';

class LogFeedPage extends StatelessWidget {
  const LogFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: kFirebaseDatabaseUrl);
    final logsRootRef = db.ref('logs'); // plain ref for deletes — Query (below) doesn't support .child()
    // Firebase push keys are chronological, so ordering by key and taking
    // the last 150 is equivalent to "most recent 150 log lines" without
    // needing a timestamp index scan.
    final logsQuery = db.ref('logs').orderByKey().limitToLast(150);

    return StreamBuilder<DatabaseEvent>(
      stream: logsQuery.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final raw = snapshot.data?.snapshot.value;
        if (raw == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Belum ada aktivitas tercatat.', textAlign: TextAlign.center),
            ),
          );
        }

        final Map<dynamic, dynamic> map = raw as Map<dynamic, dynamic>;
        // Firebase push keys sort chronologically as strings, so sorting by
        // key descending gives newest-first without needing the timestamp
        // field (which depends on the terminal's NTP sync having succeeded).
        final keys = map.keys.map((k) => k.toString()).toList()..sort((a, b) => b.compareTo(a));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: keys.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final key = keys[index];
            final data = Map<String, dynamic>.from(map[key] as Map);
            final kind = (data['kind'] as num?)?.toInt() ?? 0;
            final areaId = data['areaId'];
            final message = data['message']?.toString() ?? '';
            final ts = (data['timestamp'] as num?)?.toInt();
            final timeLabel = ts != null
                ? DateTime.fromMillisecondsSinceEpoch(ts * 1000).toString().substring(11, 19)
                : '';

            final color = logKindColor(kind);

            return Dismissible(
              key: ValueKey(key),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red[600],
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => logsRootRef.child(key).remove(),
              child: ListTile(
                dense: true,
                leading: Icon(logKindIcon(kind), color: color, size: 20),
                title: Text(message, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                subtitle: Text(
                  '${logKindLabel(kind)}${(areaId != null && areaId != 0) ? " · Area $areaId" : ""}',
                  style: TextStyle(fontSize: 11, color: color),
                ),
                trailing: Text(timeLabel, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
            );
          },
        );
      },
    );
  }
}