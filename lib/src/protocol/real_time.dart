import 'dart:typed_data';

import 'commands.dart';
import 'packet.dart';

/// Parsed real-time reading from the ring.
///
/// All real-time reading types (heart rate, SpO2, HRV) share the same
/// 4-byte response format: `[0x69, readingType, errorCode, value]`.
class RealTimeReading {
  /// Which type of reading this is (see [ReadingType] constants).
  final int type;

  /// The measured value (meaning depends on [type]):
  /// - heartRate: BPM
  /// - spo2: percentage (0-100)
  /// - hrv: milliseconds
  ///
  /// 0 while still measuring.
  final int value;

  /// Error code from the ring (0 = success / still measuring).
  final int errorCode;

  const RealTimeReading({
    required this.type,
    required this.value,
    required this.errorCode,
  });

  /// Whether this reading contains a valid (non-zero) measurement.
  bool get hasValue => value > 0 && errorCode == 0;

  @override
  String toString() => hasValue
      ? 'RealTime(type=$type, value=$value)'
      : 'RealTime(type=$type, pending, error=$errorCode)';
}

/// Creates a 16-byte packet to start a real-time measurement.
///
/// Packet layout:
///   Byte  0:  0x69 (CMD_START_REAL_TIME)
///   Byte  1:  [readingType] (e.g. ReadingType.spo2)
///   Byte  2:  0x01 (RealTimeAction.start)
///   Bytes 3-14: zeros
///   Byte  15: checksum
Uint8List makeStartRealTimeRequest(int readingType) => makePacket(
      Cmd.startRealTime,
      [readingType, RealTimeAction.start],
    );

/// Creates a 16-byte "continue" packet to keep the measurement alive.
///
/// The ring stops sending after ~5 s of silence, so the client must
/// periodically send this to keep the stream going.
Uint8List makeContinueRealTimeRequest(int readingType) => makePacket(
      Cmd.startRealTime,
      [readingType, RealTimeAction.cont],
    );

/// Creates a 16-byte packet to stop a real-time measurement.
///
/// Packet layout:
///   Byte  0:  0x6A (CMD_STOP_REAL_TIME)
///   Byte  1:  [readingType]
///   Byte  2:  0x00
///   Byte  3:  0x00
///   Bytes 4-14: zeros
///   Byte  15: checksum
Uint8List makeStopRealTimeRequest(int readingType) => makePacket(
      Cmd.stopRealTime,
      [readingType, 0, 0],
    );

/// Parses a 16-byte real-time measurement response packet.
///
/// Expected response layout:
///   Byte  0:  0x69 (CMD_START_REAL_TIME echo)
///   Byte  1:  Reading type
///   Byte  2:  Error code (0 = OK / still measuring, non-zero = error)
///   Byte  3:  Measured value (0 while still measuring)
///   Bytes 4-14: padding
///   Byte  15: checksum
///
/// Returns `null` if the packet is invalid or not a real-time response.
RealTimeReading? parseRealTimeResponse(List<int> data) {
  if (!validatePacket(data)) return null;
  if (data[0] != Cmd.startRealTime) return null;

  return RealTimeReading(
    type: data[1],
    errorCode: data[2],
    value: data[3],
  );
}
