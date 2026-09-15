import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../config.dart';

class RequestKeypadPage extends StatefulWidget {
  const RequestKeypadPage({super.key});

  @override
  State<RequestKeypadPage> createState() => _RequestKeypadPageState();
}

class _RequestKeypadPageState extends State<RequestKeypadPage> {
  String _input = '';
  bool _sending = false;
  String? _lastResult;

  void _tap(String digit) {
    if (_input.length >= 5) return;
    setState(() => _input += digit);
  }

  void _backspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _clear() => setState(() => _input = '');

  Future<void> _send() async {
    final areaId = int.tryParse(_input);
    if (areaId == null || areaId <= 0) {
      setState(() => _lastResult = 'Area ID tidak valid');
      return;
    }
    setState(() {
      _sending = true;
      _lastResult = null;
    });
    try {
      final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: kFirebaseDatabaseUrl);
      await db.ref('commands/$areaId').update({
        'requestFieldData': true,
        'requestedAt': ServerValue.timestamp,
      });
      setState(() {
        _lastResult = 'Permintaan data dikirim ke Area $areaId';
        _input = '';
      });
    } catch (e) {
      setState(() => _lastResult = 'Gagal mengirim: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _key(String label, {VoidCallback? onTap, IconData? icon, Color? color}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AspectRatio(
          aspectRatio: 1.4,
          child: Material(
            color: color ?? Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: color != null ? Colors.white : Colors.black87)
                    : Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color != null ? Colors.white : Colors.black87)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Minta Data Field Device', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Masukkan Area ID, sama seperti keypad di MT', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              _input.isEmpty ? '—' : _input,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            Text(_lastResult!, style: TextStyle(color: _lastResult!.startsWith('Permintaan') ? Colors.green[700] : Colors.red[700])),
          ],
          const SizedBox(height: 20),
          Row(children: [_key('1', onTap: () => _tap('1')), _key('2', onTap: () => _tap('2')), _key('3', onTap: () => _tap('3'))]),
          Row(children: [_key('4', onTap: () => _tap('4')), _key('5', onTap: () => _tap('5')), _key('6', onTap: () => _tap('6'))]),
          Row(children: [_key('7', onTap: () => _tap('7')), _key('8', onTap: () => _tap('8')), _key('9', onTap: () => _tap('9'))]),
          Row(children: [
            _key('', onTap: _clear, icon: Icons.clear),
            _key('0', onTap: () => _tap('0')),
            _key('', onTap: _backspace, icon: Icons.backspace_outlined),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_sending || _input.isEmpty) ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: const Text('Kirim Permintaan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}