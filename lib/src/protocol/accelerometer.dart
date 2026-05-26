import 'dart:typed_data';
import 'dart:math' as math;

import 'packet.dart';

/// Command byte for raw sensor data (accelerometer).
///
/// Not in [Cmd] because this is a less commonly used command
/// specific to raw sensor streaming.
const int cmdRawSensor = 0xA1;

/// Empirical scale observed on the development ring in resting positions.
///
/// The current raw stream values look like 12-bit STK8321 samples carried in
/// left-aligned 16-bit fields, which puts about 1 g near 8192 counts. Keep the
/// raw counts visible while this is verified across ring and firmware variants.
const double observedAccelerometerCountsPerG = 8192;

/// Parsed 3-axis accelerometer reading from the ring.
class AccelerometerReading {
  /// Acceleration on X axis (signed 16-bit).
  final int accX;

  /// Acceleration on Y axis (signed 16-bit).
  final int accY;

  /// Acceleration on Z axis (signed 16-bit).
  final int accZ;

  const AccelerometerReading({
    required this.accX,
    required this.accY,
    required this.accZ,
  });

  double get xG => accX / observedAccelerometerCountsPerG;

  double get yG => accY / observedAccelerometerCountsPerG;

  double get zG => accZ / observedAccelerometerCountsPerG;

  double get magnitudeG => math.sqrt((xG * xG) + (yG * yG) + (zG * zG));

  @override
  String toString() => 'Accel(x=$accX, y=$accY, z=$accZ)';
}

/// Creates a 16-byte packet to enable raw accelerometer streaming.
///
/// Stock firmware delivers data at ~1 Hz. Custom firmware (ATC_RF03_Ring)
/// can deliver faster rates.
///
/// Packet layout:
///   Byte  0:  0xA1 (raw sensor command)
///   Byte  1:  0x04 (enable)
///   Byte  2:  0x04 (accelerometer mode)
///   Bytes 3-14: zeros
///   Byte  15: checksum
Uint8List makeAccelerometerStartRequest() =>
    makePacket(cmdRawSensor, [0x04, 0x04]);

/// Creates a 16-byte packet to disable raw accelerometer streaming.
///
/// Packet layout:
///   Byte  0:  0xA1 (raw sensor command)
///   Byte  1:  0x02 (disable)
///   Bytes 2-14: zeros
///   Byte  15: checksum
Uint8List makeAccelerometerStopRequest() => makePacket(cmdRawSensor, [0x02]);

/// Parses a 16-byte raw accelerometer response packet.
///
/// Expected response layout:
///   Byte  0:     0xA1 (raw sensor command echo)
///   Byte  1:     0x03 (data sub-type)
///   Bytes 2-3:   accX as signed 16-bit big-endian
///   Bytes 4-5:   accY as signed 16-bit big-endian
///   Bytes 6-7:   accZ as signed 16-bit big-endian
///   Bytes 8-14:  padding
///   Byte  15:    checksum
///
/// Returns `null` if the packet is invalid or not an accelerometer response.
AccelerometerReading? parseAccelerometerResponse(List<int> data) {
  if (!validatePacket(data)) return null;
  if (data[0] != cmdRawSensor) return null;
  if (data[1] != 0x03) return null; // only parse data packets

  return AccelerometerReading(
    accX: _toSigned16((data[2] << 8) | data[3]),
    accY: _toSigned16((data[4] << 8) | data[5]),
    accZ: _toSigned16((data[6] << 8) | data[7]),
  );
}

/// Converts an unsigned 16-bit value to signed.
int _toSigned16(int value) {
  if (value >= 0x8000) return value - 0x10000;
  return value;
}
