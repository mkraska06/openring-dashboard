import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';

import '../protocol/packet.dart';

// ---------------------------------------------------------------------------
// BLE UUIDs for the Colmi ring's Nordic UART Service (NUS)
// ---------------------------------------------------------------------------

/// Primary GATT service exposed by the ring.
const String colmiServiceUuid = '6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E';

/// Characteristic the *client writes to* (ring's RX line).
const String writeCharUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';

/// Characteristic the *ring sends notifications on* (ring's TX line).
const String notifyCharUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

/// Device-name prefixes that identify a Colmi ring during scanning.
const List<String> colmiPrefixes = ['R02', 'R03', 'R06', 'R09'];

// ---------------------------------------------------------------------------
// Connection state
// ---------------------------------------------------------------------------

enum BleConnectionStatus { disconnected, scanning, connecting, connected }

// ---------------------------------------------------------------------------
// BleService – central BLE communication layer
// ---------------------------------------------------------------------------

class BleService {
  BleService() {
    // Listen for unexpected disconnects from the platform layer.
    UniversalBle.onConnectionChange = _onConnectionChange;
  }

  // -- hex logging helper ---------------------------------------------------

  /// Returns a space-separated hex string, e.g. "03 00 00 ... 03".
  static String hex(Uint8List b) =>
      b.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');

  /// Optional callback for on-screen debug logging.
  /// Set by the UI layer to receive "[TX] ..." and "[RX] ..." lines.
  void Function(String line)? onDebugLog;

  // -- internal state -------------------------------------------------------

  String? _deviceId;
  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  Timer? _scanTimer;
  StreamSubscription<Uint8List>? _notifySub;

  /// Broadcast controller so multiple listeners can consume packets.
  final _packetController = StreamController<Uint8List>.broadcast();

  /// Broadcast controller for connection-status changes.
  final _statusController =
      StreamController<BleConnectionStatus>.broadcast();

  /// Broadcast controller for scan results (filtered to Colmi rings).
  final _scanController = StreamController<BleDevice>.broadcast();

  // -- public getters -------------------------------------------------------

  BleConnectionStatus get status => _status;
  String? get connectedDeviceId => _deviceId;

  /// Stream of validated 16-byte packets received from the ring.
  Stream<Uint8List> get packetStream => _packetController.stream;

  /// Stream of connection-status transitions.
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;

  /// Stream of discovered Colmi ring devices during a scan.
  Stream<BleDevice> get scanResults => _scanController.stream;

  // -- scanning -------------------------------------------------------------

  /// Returns `true` if [device] looks like a Colmi ring.
  ///
  /// Matches when the name starts with one of [colmiPrefixes]
  /// or contains the word "Colmi" (case-insensitive).
  static bool isColmiRing(BleDevice device) {
    final name = device.name ?? '';
    if (name.isEmpty) return false;
    if (colmiPrefixes.any((p) => name.startsWith(p))) return true;
    if (name.toLowerCase().contains('colmi')) return true;
    return false;
  }

  /// Starts scanning for Colmi rings.
  ///
  /// Discovered devices are emitted on [scanResults].
  /// Scanning stops automatically after [timeout] (default 10 s)
  /// or when [stopScan] is called.
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_status == BleConnectionStatus.scanning) return;

    _setStatus(BleConnectionStatus.scanning);

    // Register scan callback – filter to Colmi devices only.
    UniversalBle.onScanResult = (device) {
      if (isColmiRing(device)) {
        _scanController.add(device);
      }
    };

    // Use name-prefix filter so the platform pre-filters where possible.
    await UniversalBle.startScan(
      scanFilter: ScanFilter(withNamePrefix: colmiPrefixes),
    );

    // Auto-stop after timeout.
    _scanTimer?.cancel();
    _scanTimer = Timer(timeout, stopScan);
  }

  /// Stops an ongoing scan.
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    UniversalBle.onScanResult = null;

    try {
      await UniversalBle.stopScan();
    } catch (_) {
      // stopScan may throw if no scan is active – safe to ignore.
    }

    // Only reset status if we're not already connected / connecting.
    if (_status == BleConnectionStatus.scanning) {
      _setStatus(BleConnectionStatus.disconnected);
    }
  }

  // -- connection -----------------------------------------------------------

  /// Connects to the ring at [deviceId], discovers the NUS service,
  /// and subscribes to notifications on the TX characteristic.
  ///
  /// Throws on failure (timeout, missing service, etc.).
  Future<void> connect(String deviceId) async {
    // Stop any running scan first.
    await stopScan();

    _setStatus(BleConnectionStatus.connecting);
    _deviceId = deviceId;

    try {
      // 1. Establish the BLE connection.
      await UniversalBle.connect(deviceId);

      // 2. Discover GATT services and locate the Colmi NUS service.
      final services = await UniversalBle.discoverServices(deviceId);

      final hasService = services.any(
        (s) => s.uuid.toUpperCase() == colmiServiceUuid,
      );
      if (!hasService) {
        throw StateError(
          'Ring does not expose the expected NUS service ($colmiServiceUuid)',
        );
      }

      // 3. Enable notifications on the TX characteristic so we receive
      //    response packets from the ring.
      await UniversalBle.subscribeNotifications(
        deviceId,
        colmiServiceUuid,
        notifyCharUuid,
      );

      // 4. Forward incoming bytes into our packet stream.
      //    Only emit packets that pass the checksum validation.
      _notifySub?.cancel();
      _notifySub = UniversalBle.characteristicValueStream(
        deviceId,
        notifyCharUuid,
      ).listen(
        (data) {
          final line = '[RX] ${hex(data)}';
          debugPrint(line);
          onDebugLog?.call(line);
          if (data.length == packetLength && validatePacket(data)) {
            _packetController.add(data);
          }
        },
        onError: (Object e) {
          // Notification stream error – treat as disconnect.
          _handleDisconnect();
        },
      );

      _setStatus(BleConnectionStatus.connected);
    } catch (e) {
      // Roll back on any failure.
      _deviceId = null;
      _setStatus(BleConnectionStatus.disconnected);
      rethrow;
    }
  }

  /// Gracefully disconnects from the currently connected ring.
  Future<void> disconnect() async {
    final id = _deviceId;
    if (id == null) return;

    try {
      await _notifySub?.cancel();
      _notifySub = null;

      await UniversalBle.unsubscribe(id, colmiServiceUuid, notifyCharUuid);
      await UniversalBle.disconnect(id);
    } catch (_) {
      // Best-effort – the link may already be down.
    } finally {
      _deviceId = null;
      _setStatus(BleConnectionStatus.disconnected);
    }
  }

  // -- data transfer --------------------------------------------------------

  /// Sends a 16-byte [packet] to the ring's write characteristic.
  ///
  /// Uses write-without-response for speed (matches the Python client).
  /// Throws [StateError] if no ring is connected.
  Future<void> sendPacket(Uint8List packet) async {
    final id = _deviceId;
    if (id == null || _status != BleConnectionStatus.connected) {
      throw StateError('Cannot send packet – no ring connected');
    }

    await UniversalBle.write(
      id,
      colmiServiceUuid,
      writeCharUuid,
      packet,
      withoutResponse: true,
    );
    final line = '[TX] ${hex(packet)}';
    debugPrint(line);
    onDebugLog?.call(line);
  }

  // -- lifecycle ------------------------------------------------------------

  /// Releases all resources. Call when the service is no longer needed.
  void dispose() {
    _scanTimer?.cancel();
    _notifySub?.cancel();
    UniversalBle.onScanResult = null;
    UniversalBle.onConnectionChange = null;
    _packetController.close();
    _statusController.close();
    _scanController.close();
  }

  // -- private helpers ------------------------------------------------------

  void _setStatus(BleConnectionStatus next) {
    if (_status == next) return;
    _status = next;
    _statusController.add(next);
  }

  /// Called by universal_ble when the connection state changes.
  void _onConnectionChange(String deviceId, bool isConnected, String? error) {
    if (deviceId != _deviceId) return;
    if (!isConnected) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _notifySub?.cancel();
    _notifySub = null;
    _deviceId = null;
    _setStatus(BleConnectionStatus.disconnected);
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Singleton [BleService] instance, kept alive for the app's lifetime.
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(service.dispose);
  return service;
});

/// Current [BleConnectionStatus] as a stream.
final bleStatusProvider = StreamProvider<BleConnectionStatus>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.statusStream;
});

/// Discovered Colmi ring devices during an active scan.
final scanResultsProvider = StreamProvider<BleDevice>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.scanResults;
});

/// Validated 16-byte packets received from the connected ring.
final packetStreamProvider = StreamProvider<Uint8List>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.packetStream;
});
