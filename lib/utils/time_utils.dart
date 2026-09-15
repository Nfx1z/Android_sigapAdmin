/// Converts a Firebase timestamp (either seconds or milliseconds) to DateTime.
///
/// Firebase Realtime Database `ServerValue.timestamp` writes milliseconds.
/// However, some devices (ESP32 firmware) send Unix seconds.
/// This helper detects and handles both.
DateTime parseFirebaseTimestamp(int? timestamp) {
  if (timestamp == null) return DateTime.now();
  // If the value is less than 10^10, assume it's in seconds (Unix epoch).
  if (timestamp < 10000000000) {
    timestamp *= 1000;
  }
  return DateTime.fromMillisecondsSinceEpoch(timestamp);
}