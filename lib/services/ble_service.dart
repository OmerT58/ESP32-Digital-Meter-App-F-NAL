/// ble_service.dart
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// ── ESP32 BLE identifiers ─────────────────────────────────────────────────
const String _kTargetName   = 'ESP32_Digital_Meter_BLE';
const String _kServiceUuid  = '4fa10001-5012-4c19-b29c-152514100000';
const String _kCharUuid     = '4fa10002-5012-4c19-b29c-152514100000'; // notify char
// ─────────────────────────────────────────────────────────────────────────

enum BleConnectionState { idle, scanning, connecting, connected, error }

class BleService extends ChangeNotifier {
  BleService._();
  static final BleService instance = BleService._();

  BleConnectionState connectionState = BleConnectionState.idle;
  List<double> latestData = [0.0, 0.0, 0.0, 0.0, 0.0];
  String? errorMessage;
  String statusMessage = 'Idle';
  String? connectedDeviceName;

  final _dataStreamController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get dataStream => _dataStreamController.stream;

  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>?        _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  StreamSubscription<bool>?             _isScanSub; // guard isScanning listener

  bool get isConnected => connectionState == BleConnectionState.connected;

  bool _isSimulationEnabled = false;

  double _currentRoll = 0.0;
  double _currentPitch = 0.0;
  double _currentYaw = 0.0;
  double _lastAx = 0.0;
  double _lastAy = 0.0;
  double _lastAz = 0.0;

  void setSimulationEnabled(bool enabled) {
    _isSimulationEnabled = enabled;
    if (_isSimulationEnabled && isConnected) {
      final mockedData = List<double>.from(latestData);
      mockedData[0] = 500.0;
      latestData = mockedData;
      _dataStreamController.add(mockedData);
      notifyListeners();
    }
  }

  // ── Permissions ─────────────────────────────────────────────────────────
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((s) => s.isGranted);
  }

  // ── Scan ─────────────────────────────────────────────────────────────────
  Future<void> startScan() async {
    if (connectionState == BleConnectionState.scanning  ||
        connectionState == BleConnectionState.connecting ||
        connectionState == BleConnectionState.connected) {
      return;
    }

    if (!await requestPermissions()) {
      _setError('Bluetooth and Location permissions are required.');
      return;
    }

    if (!await Permission.location.serviceStatus.isEnabled) {
      _setError('Please enable Location Services (GPS) for Bluetooth scanning.');
      return;
    }

    _setConnectionState(BleConnectionState.scanning);
    _setStatus('Permissions Granted. Scanning...');
    errorMessage = null;

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        _setError('Please turn on Bluetooth.');
        return;
      }
    }

    await FlutterBluePlus.stopScan();
    await _isScanSub?.cancel(); // cancel previous isScanning listener

    _scanSub = FlutterBluePlus.scanResults.listen(_onScanResult);

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));

    // Fire "not found" only once per scan session
    _isScanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && connectionState == BleConnectionState.scanning) {
        _setError('Device "$_kTargetName" not found. Tap to retry.');
      }
    });
  }

  // ── Disconnect ───────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    await _cleanUp();
    _setConnectionState(BleConnectionState.idle);
  }

  // ── Scan result handler ──────────────────────────────────────────────────
  Future<void> _onScanResult(List<ScanResult> results) async {
    for (final r in results) {
      if (r.device.advName.isNotEmpty) {
        debugPrint('[BLE] Discovered: ${r.device.advName}');
      }
    }

    final targets = results.where((r) => r.device.advName == _kTargetName);
    if (targets.isEmpty) return;

    _device = targets.first.device;

    // Stop scan before connecting
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;

    _setConnectionState(BleConnectionState.connecting);
    await _connect(_device!);
  }

  // ── Connection (with retry) ──────────────────────────────────────────────
  Future<void> _connect(BluetoothDevice device, {int attempt = 1}) async {
    try {
      _setStatus('Connecting… (Attempt $attempt/3)');

      // 20-second timeout gives the ESP32 enough time to complete pairing
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 20),
      );

      debugPrint('[BLE] TCP link established. Requesting MTU...');

      // Request larger MTU so 30-ms sensor strings never fragment
      try {
        await device.requestMtu(512);
        debugPrint('[BLE] MTU negotiated to ${await device.mtu.first}');
      } catch (mtuErr) {
        // Non-fatal: some Android versions handle this internally
        debugPrint('[BLE] MTU request skipped: $mtuErr');
      }

      // Small settle delay – ESP32 NimBLE needs ~200 ms after connection
      // before GATT service discovery is reliable
      await Future.delayed(const Duration(milliseconds: 400));

      // Attach disconnect watcher BEFORE service discovery
      _connStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            connectionState == BleConnectionState.connected) {
          _handleDisconnect();
        }
      });

      _setStatus('Discovering services…');
      await _discoverServices(device);

    } catch (e) {
      debugPrint('[BLE] Connection attempt $attempt failed: $e');
      if (attempt < 3) {
        _setStatus('Connection failed. Retrying in 2 s…');
        await Future.delayed(const Duration(seconds: 2));
        await _connect(device, attempt: attempt + 1);
      } else {
        _setError('Connection failed after 3 attempts.\n$e');
      }
    }
  }

  // ── GATT service + characteristic discovery ──────────────────────────────
  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();

    debugPrint('[BLE] Discovered ${services.length} service(s):');
    for (final s in services) {
      debugPrint('  Service: ${s.uuid}');
      for (final c in s.characteristics) {
        debugPrint('    Char: ${c.uuid} props=${c.properties}');
      }
    }

    BluetoothCharacteristic? notifyChar;

    for (final svc in services) {
      final svcId = svc.uuid.toString().toLowerCase();

      // Accept exact match OR partial last-segment match for robustness
      if (svcId == _kServiceUuid || svcId.endsWith(_kServiceUuid.split('-').last)) {
        for (final c in svc.characteristics) {
          final cId = c.uuid.toString().toLowerCase();
          if (cId == _kCharUuid || cId.endsWith(_kCharUuid.split('-').last)) {
            notifyChar = c;
            break;
          }
        }
      }
      if (notifyChar != null) break;
    }

    if (notifyChar == null) {
      // Provide a detailed log to aid debugging
      final uuids = services.map((s) => s.uuid.toString()).join(', ');
      _setError('Notify char not found.\nAvailable services: $uuids');
      return;
    }

    await notifyChar.setNotifyValue(true);
    _notifySub = notifyChar.onValueReceived.listen(_onNotification);

    connectedDeviceName =
        device.advName.isNotEmpty ? device.advName : device.remoteId.str;
    _setStatus('Connected and subscribed.');
    _setConnectionState(BleConnectionState.connected);
    debugPrint('[BLE] ✓ Subscribed to ${notifyChar.uuid}');
  }

  // ── Data notification handler ────────────────────────────────────────────
  // New ESP32 format (8 fields):
  //   gyro_x, gyro_y, gyro_z, acc_x, acc_y, acc_z, distance_mm, buttonState
  // Legacy format (5 fields):
  //   distance_mm, roll, pitch, yaw, buttonState
  void _onNotification(List<int> bytes) {
    try {
      final raw   = String.fromCharCodes(bytes).trim();
      final parts = raw.split(',');

      double dist = 0, roll = 0, pitch = 0, yaw = 0, btn = 0;
      double gx = 0, gy = 0, gz = 0;

      if (parts.length >= 8) {
        // ── New 8-field ESP32 format ─────────────────────────────
        final gxRaw = double.parse(parts[0].trim());
        final gyRaw = double.parse(parts[1].trim());
        final gzRaw = double.parse(parts[2].trim());
        final axRaw = double.parse(parts[3].trim());
        final ayRaw = double.parse(parts[4].trim());
        final azRaw = double.parse(parts[5].trim());
        dist  = double.parse(parts[6].trim());
        btn   = double.parse(parts[7].trim());

        // 1. Scaling
        gx = gxRaw / 131.0;
        gy = gyRaw / 131.0;
        gz = gzRaw / 131.0;
        double ax = axRaw / 16384.0;
        double ay = ayRaw / 16384.0;
        double az = azRaw / 16384.0;

        // 2. Deadzone (Noise Gate)
        if (gx > -2.5 && gx < 2.5) gx = 0.0;
        if (gy > -2.5 && gy < 2.5) gy = 0.0;
        if (gz > -2.5 && gz < 2.5) gz = 0.0;

        if ((ax - _lastAx).abs() < 0.05) ax = _lastAx;
        if ((ay - _lastAy).abs() < 0.05) ay = _lastAy;
        if ((az - _lastAz).abs() < 0.05) az = _lastAz;
        _lastAx = ax;
        _lastAy = ay;
        _lastAz = az;

        // 3. Sensor Fusion (Complementary Filter)
        final double dt = 0.03;
        
        double accRoll = math.atan2(ay, az) * 180.0 / math.pi;
        double accPitch = math.atan2(-ax, math.sqrt(ay * ay + az * az)) * 180.0 / math.pi;

        _currentRoll = (0.98 * (_currentRoll + gx * dt)) + (0.02 * accRoll);
        _currentPitch = (0.98 * (_currentPitch + gy * dt)) + (0.02 * accPitch);
        _currentYaw = _currentYaw + (gz * dt);

        roll = _currentRoll;
        pitch = _currentPitch;
        yaw = _currentYaw;
      } else if (parts.length >= 5) {
        // ── Legacy 5-field format (simulation / old firmware) ────
        dist  = double.parse(parts[0].trim());
        roll  = double.parse(parts[1].trim());
        pitch = double.parse(parts[2].trim());
        yaw   = double.parse(parts[3].trim());
        btn   = double.parse(parts[4].trim());
      } else {
        return; // malformed packet, discard
      }

      if (_isSimulationEnabled) dist = 500.0;

      // Internal data layout: [dist, roll, pitch, yaw, btn, gx, gy, gz]
      final data = [dist, roll, pitch, yaw, btn, gx, gy, gz];
      latestData = data;
      _dataStreamController.add(data);
      // Removed notifyListeners() to optimize UI repaints
    } catch (e) {
      debugPrint('[BLE] Parse error: $e');
    }
  }

  // ── Disconnect handler ───────────────────────────────────────────────────
  void _handleDisconnect() {
    _cleanUp();
    _setError('Device disconnected. Reconnecting…');
    Future.delayed(const Duration(seconds: 2), startScan);
  }

  // ── Clean up all subscriptions ───────────────────────────────────────────
  Future<void> _cleanUp() async {
    await _notifySub?.cancel();
    await _connStateSub?.cancel();
    await _scanSub?.cancel();
    await _isScanSub?.cancel();
    _notifySub        = null;
    _connStateSub     = null;
    _scanSub          = null;
    _isScanSub        = null;
    connectedDeviceName = null;
    try { await _device?.disconnect(); } catch (_) {}
    _device = null;
  }

  // ── State helpers ────────────────────────────────────────────────────────
  void _setConnectionState(BleConnectionState state) {
    connectionState = state;
    notifyListeners();
  }

  void _setStatus(String message) {
    statusMessage = message;
    notifyListeners();
  }

  void _setError(String message) {
    errorMessage    = message;
    statusMessage   = 'Error';
    connectionState = BleConnectionState.error;
    notifyListeners();
  }
}
