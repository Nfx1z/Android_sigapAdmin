import 'package:flutter/material.dart';

// Mirrors DETAIL_* in hq.txt exactly — keep these two files in sync if the
// firmware's enum ever changes.
const int kDetailNone = 0;
const int kDetailHelp = 1;
const int kDetailAck = 2;
const int kDetailAlarm = 3;
const int kDetailCancel = 4;
const int kDetailData = 5;
const int kDetailSubfield = 6;
const int kDetailHeartbeat = 7;
const int kDetailBeacon = 8;
const int kDetailWarning = 9;
const int kDetailSfMissing = 10;
const int kDetailReqOut = 11;
const int kDetailAckOut = 12;
const int kDetailOffline = 13;

String logKindLabel(int kind) {
  switch (kind) {
    case kDetailHelp: return 'Help';
    case kDetailAck: return 'Ack';
    case kDetailAlarm: return 'Alarm';
    case kDetailCancel: return 'Batal Help';
    case kDetailData: return 'Data Lapangan';
    case kDetailSubfield: return 'Data Sub-Field';
    case kDetailHeartbeat: return 'Heartbeat';
    case kDetailBeacon: return 'Beacon Hilang';
    case kDetailWarning: return 'Warning';
    case kDetailSfMissing: return 'Sub-Field Hilang';
    case kDetailReqOut: return 'Request Data';
    case kDetailAckOut: return 'Ack Terkirim';
    case kDetailOffline: return 'Device Offline';
    default: return 'Info';
  }
}

// Matches COLOR_LOG_* usage at each addLogEntry() call site in hq.txt.
Color logKindColor(int kind) {
  switch (kind) {
    case kDetailHelp:
    case kDetailCancel:
    case kDetailSfMissing:
    case kDetailOffline:
      return Colors.orange[700]!;
    case kDetailAck:
    case kDetailAckOut:
      return Colors.green[600]!;
    case kDetailAlarm:
    case kDetailBeacon:
    case kDetailWarning:
      return Colors.red[600]!;
    case kDetailData:
    case kDetailSubfield:
    case kDetailReqOut:
      return Colors.cyan[700]!;
    case kDetailHeartbeat:
    default:
      return Colors.grey[600]!;
  }
}

IconData logKindIcon(int kind) {
  switch (kind) {
    case kDetailHelp: return Icons.warning_amber;
    case kDetailAck:
    case kDetailAckOut:
      return Icons.check_circle_outline;
    case kDetailAlarm: return Icons.crisis_alert;
    case kDetailCancel: return Icons.cancel_outlined;
    case kDetailData:
    case kDetailSubfield:
      return Icons.sensors;
    case kDetailHeartbeat: return Icons.favorite_border;
    case kDetailBeacon: return Icons.location_off;
    case kDetailWarning: return Icons.report_problem_outlined;
    case kDetailSfMissing: return Icons.link_off;
    case kDetailReqOut: return Icons.send_outlined;
    case kDetailOffline: return Icons.wifi_off;
    default: return Icons.info_outline;
  }
}