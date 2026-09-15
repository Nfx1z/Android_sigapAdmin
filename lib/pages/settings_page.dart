import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../config.dart';

// Normalizes to the digit-only, 62-prefixed format wa.me expects — same
// cleaning rule the old hardcoded _sendWhatsApp used, so numbers added here
// work with the existing WhatsApp flow without any other change.
String normalizeIndonesianNumber(String raw) {
  String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0')) digits = '62${digits.substring(1)}';
  if (!digits.startsWith('62')) digits = '62$digits';
  return digits;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _controller = TextEditingController();
  bool _adding = false;
  String? _error;

  late final DatabaseReference _numbersRef;

  @override
  void initState() {
    super.initState();
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: kFirebaseDatabaseUrl);
    _numbersRef = db.ref('settings/notifyNumbers');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addNumber() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    final normalized = normalizeIndonesianNumber(raw);
    if (normalized.length < 10 || normalized.length > 15) {
      setState(() => _error = 'Nomor tidak valid');
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await _numbersRef.push().set(normalized);
      _controller.clear();
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeNumber(String key, String number) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Nomor?'),
        content: Text('Nomor $number tidak akan lagi menerima notifikasi.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _numbersRef.child(key).remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Nomor Penerima Notifikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          'Setiap laporan yang tidak dibatalkan dalam 5 menit akan dikirim ke semua nomor di bawah ini.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '08xx atau 62xx',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onSubmitted: (_) => _addNumber(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _adding ? null : _addNumber,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                ),
                child: _adding
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StreamBuilder<DatabaseEvent>(
          stream: _numbersRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            }
            final raw = snapshot.data?.snapshot.value;
            if (raw == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Belum ada nomor terdaftar. Tambahkan minimal satu nomor di atas.',
                  style: TextStyle(color: Colors.orange[800]),
                  textAlign: TextAlign.center,
                ),
              );
            }
            final Map<dynamic, dynamic> map = raw as Map<dynamic, dynamic>;
            final entries = map.entries.toList();

            return Column(
              children: entries.map((e) {
                final key = e.key.toString();
                final number = e.value.toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.phone, color: Color(0xFF25D366)),
                    title: Text('+$number', style: const TextStyle(fontFamily: 'monospace')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeNumber(key, number),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}