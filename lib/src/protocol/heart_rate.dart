import 'dart:typed_data';

import 'commands.dart';
import 'packet.dart';

/// Parsed real-time heart-rate reading from the ring.
class HeartRateReading {
  /// Measured heart rate in BPM, or 0 if still measuring.
  final int bpm;

  /// Error code from the ring (0 = success / still measuring).
  final int errorCode;

  const HeartRateReading({required this.bpm, required this.errorCode});

  /// Whether this reading contains a valid (non-zero) measurement.
  bool get hasValue => bpm > 0 && errorCode == 0;

  @override
  String toString() =>
      hasValue ? 'HR($bpm bpm)' : 'HR(pending, error=$errorCode)';
}

/// Creates a 16-byte packet to start real-time heart-rate measurement.
///
/// Packet layout:
///   Byte  0:  0x69 (CMD_START_REAL_TIME)
///   Byte  1:  0x01 (ReadingType.heartRate)
///   Byte  2:  0x01 (RealTimeAction.start)
///   Bytes 3-14: zeros
///   Byte  15: checksum
Uint8List makeStartHeartRateRequest() => makePacket(
      Cmd.startRealTime,
      [ReadingType.heartRate, RealTimeAction.start],
    );

/// Creates a 16-byte packet to tell the ring we're still listening.
///
/// The ring stops sending after ~5 s of silence, so the client must
/// periodically send a "continue" packet to keep the stream alive.
///
/// Packet layout:
///   Byte  0:  0x69 (CMD_START_REAL_TIME)
///   Byte  1:  0x01 (ReadingType.heartRate)
///   Byte  2:  0x03 (RealTimeAction.continue)
///   Bytes 3-14: zeros
///   Byte  15: checksum
Uint8List makeContinueHeartRateRequest() => makePacket(
      Cmd.startRealTime,
      [ReadingType.heartRate, RealTimeAction.cont],
    );

/// Creates a 16-byte packet to stop real-time heart-rate measurement.
///
/// Packet layout:
///   Byte  0:  0x6A (CMD_STOP_REAL_TIME)
///   Byte  1:  0x01 (ReadingType.heartRate)
///   Byte  2:  0x00
///   Byte  3:  0x00
///   Bytes 4-14: zeros
///   Byte  15: checksum
Uint8List makeStopHeartRateRequest() => makePacket(
      Cmd.stopRealTime,
      [ReadingType.heartRate, 0, 0],
    );

/// Parses a 16-byte real-time heart-rate response packet.
///
/// Expected response layout:
///   Byte  0:  0x69 (CMD_START_REAL_TIME echo)
///   Byte  1:  Reading type (should be 0x01 for heart rate)
///   Byte  2:  Error code (0 = OK / still measuring, non-zero = error)
///   Byte  3:  Heart rate value in BPM (0 while still measuring)
///   Bytes 4-14: padding
///   Byte  15: checksum
///
/// Returns `null` if the packet is invalid or not a heart-rate response.
HeartRateReading? parseHeartRateResponse(List<int> data) {
  if (!validatePacket(data)) return null;
  if (data[0] != Cmd.startRealTime) return null;
  if (data[1] != ReadingType.heartRate) return null;

  return HeartRateReading(
    errorCode: data[2],
    bpm: data[3],
  );
}
