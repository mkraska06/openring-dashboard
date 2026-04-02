import 'dart:typed_data';

import 'commands.dart';
import 'packet.dart';

/// Creates a 16-byte packet to make the ring's LEDs blink twice.
///
/// Useful for identifying which ring is connected.
Uint8List makeBlinkTwicePacket() => makePacket(Cmd.blinkTwice);

/// Creates a 16-byte packet to reboot the ring.
///
/// The ring will disconnect after receiving this command.
///
/// Packet layout:
///   Byte  0:  0x08 (CMD_REBOOT)
///   Byte  1:  0x01
///   Bytes 2-14: zeros
///   Byte  15: checksum
Uint8List makeRebootPacket() => makePacket(Cmd.reboot, [0x01]);
