/// ble_service.dart
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const String _kTargetName = 'DigitalMeter_Pro';
const String _kServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const String _kCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

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
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;

  bool get isConnected => connectionState == BleConnectionState.connected;

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = true;
    for (var status in statuses.values) {
      if (!status.isGranted) {
        allGranted = false;
        break;
      }
    }
    return allGranted;
  }

  Future<void> startScan() async {
    if (connectionState == BleConnectionState.scanning ||
        connectionState == BleConnectionState.connecting ||
        connectionState == BleConnectionState.connected) {
      return;
    }

    bool hasPermissions = await requestPermissions();
    if (!hasPermissions) {
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

    _scanSub = FlutterBluePlus.scanResults.listen(_onScanResult);

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      // withNames: [_kTargetName], // Removed to relax scanning and discover all
    );

    FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && connectionState == BleConnectionState.scanning) {
        _setError('Device "$_kTargetName" not found. Tap to retry.');
      }
    });
  }

  Future<void> disconnect() async {
    await _cleanUp();
    _setConnectionState(BleConnectionState.idle);
  }

  Future<void> _onScanResult(List<ScanResult> results) async {
    for (var r in results) {
       if (r.device.advName.isNotEmpty) {
          debugPrint('Discovered: ${r.device.advName}');
       }
    }
    
    final target = results.where((r) => r.device.advName == _kTargetName);
    if (target.isEmpty) return;

    final result = target.first;
    _device = result.device;

    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();

    _setConnectionState(BleConnectionState.connecting);
    await _connect(result.device);
  }

  Future<void> _connect(BluetoothDevice device, {int attempt = 1}) async {
    try {
      _setStatus('Connecting... (Attempt $attempt/3)');
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));
      _connStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            connectionState == BleConnectionState.connected) {
          _handleDisconnect();
        }
      });

      _setStatus('Services Discovered...');
      await _discoverServices(device);
    } catch (e) {
      if (attempt < 3) {
        _setStatus('Connection failed. Retrying...');
        await Future.delayed(const Duration(seconds: 2));
        await _connect(device, attempt: attempt + 1);
      } else {
        _setError('Connection failed after 3 attempts: $e');
      }
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    BluetoothCharacteristic? char;

    for (final s in services) {
      if (s.uuid.toString().toLowerCase() == _kServiceUuid) {
        for (final c in s.characteristics) {
          if (c.uuid.toString().toLowerCase() == _kCharUuid) {
            char = c;
            break;
          }
        }
      }
    }

    if (char == null) {
      _setError('Notify characteristic not found.');
      return;
    }

    await char.setNotifyValue(true);
    _notifySub = char.onValueReceived.listen(_onNotification);

    connectedDeviceName = device.advName.isNotEmpty ? device.advName : device.remoteId.str;
    _setStatus('Connected and subscribed.');
    _setConnectionState(BleConnectionState.connected);
  }

  void _onNotification(List<int> bytes) {
    try {
      final raw = String.fromCharCodes(bytes).trim();
      final parts = raw.split(',');
      if (parts.length >= 5) {
        final dist = double.parse(parts[0].trim());
        final roll = double.parse(parts[1].trim());
        final pitch = double.parse(parts[2].trim());
        final yaw = double.parse(parts[3].trim());
        final btn = double.parse(parts[4].trim());
        final data = [dist, roll, pitch, yaw, btn];
        latestData = data;
        _dataStreamController.add(data);
        notifyListeners();
      }
    } catch (_) {}
  }

  void _handleDisconnect() {
    _cleanUp();
    _setError('Device disconnected. Reconnecting...');
    Future.delayed(const Duration(seconds: 2), startScan);
  }

  Future<void> _cleanUp() async {
    await _notifySub?.cancel();
    await _connStateSub?.cancel();
    await _scanSub?.cancel();
    _notifySub = null;
    _connStateSub = null;
    _scanSub = null;
    connectedDeviceName = null;
    try { await _device?.disconnect(); } catch (_) {}
    _device = null;
  }

  void _setConnectionState(BleConnectionState state) {
    connectionState = state;
    notifyListeners();
  }

  void _setStatus(String message) {
    statusMessage = message;
    notifyListeners();
  }

  void _setError(String message) {
    errorMessage = message;
    statusMessage = 'Error';
    connectionState = BleConnectionState.error;
    notifyListeners();
  }
}
