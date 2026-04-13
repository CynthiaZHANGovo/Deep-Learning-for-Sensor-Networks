import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static const String targetDeviceName = 'SportMusicNano';
  static final Guid targetServiceUuid =
      Guid('19B10000-E8F2-537E-4F6C-D104768A1214');
  static final Guid targetCharacteristicUuid =
      Guid('19B10001-E8F2-537E-4F6C-D104768A1214');

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  final StreamController<String> _sportController =
      StreamController<String>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get sportStream => _sportController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _sportCharacteristic;
  ScanResult? _targetScanResult;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;

  bool _isScanning = false;

  bool get hasDiscoveredDevice => _targetScanResult != null;
  bool get isConnected => _connectedDevice != null && _sportCharacteristic != null;

  Future<void> startScan() async {
    if (_isScanning) {
      _emitStatus('Scan already in progress.');
      return;
    }

    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) {
      _emitStatus('BLE is not supported on this device.');
      return;
    }

    _targetScanResult = null;
    _isScanning = true;
    _emitStatus('Scanning for $targetDeviceName...');

    await _notificationSubscription?.cancel();
    await _scanSubscription?.cancel();

    final completer = Completer<void>();

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) async {
        for (final result in results) {
          final name = result.device.platformName.trim();
          if (name == targetDeviceName) {
            _targetScanResult = result;
            _emitStatus('Found $targetDeviceName. Ready to connect.');
            if (!completer.isCompleted) {
              completer.complete();
            }
            await FlutterBluePlus.stopScan();
            break;
          }
        }
      },
      onError: (Object error) {
        _emitStatus('Scan failed: $error');
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    try {
      // Android runtime BLE permissions are requested by the plugin when scan
      // starts, as long as the matching Manifest permissions are present.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
      );
      await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {},
      );
    } catch (error) {
      _emitStatus('Unable to start scan: $error');
    } finally {
      _isScanning = false;
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;

      if (_targetScanResult == null) {
        _emitStatus('$targetDeviceName was not found.');
      }
    }
  }

  Future<void> connectToTargetDevice() async {
    if (_targetScanResult == null) {
      _emitStatus('Scan first so the app can find $targetDeviceName.');
      return;
    }

    await disconnect(emitStatus: false);

    final device = _targetScanResult!.device;
    _connectedDevice = device;
    _emitStatus('Connecting to ${device.platformName}...');

    try {
      await device.connect(timeout: const Duration(seconds: 10));
    } on Exception catch (_) {
      // Some Android devices report "already connected" when reconnecting fast.
    } catch (error) {
      _connectedDevice = null;
      _emitStatus('Connection failed: $error');
      _connectionController.add(false);
      return;
    }

    _connectionSubscription = device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.disconnected) {
        await _resetConnectionState();
        _emitStatus('Device disconnected.');
        _connectionController.add(false);
      }
    });

    try {
      final services = await device.discoverServices();
      final service = services.cast<BluetoothService?>().firstWhere(
            (candidate) => candidate?.uuid == targetServiceUuid,
            orElse: () => null,
          );

      if (service == null) {
        _emitStatus('Required BLE service was not found on the device.');
        await disconnect(emitStatus: false);
        return;
      }

      final characteristic =
          service.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
                (candidate) => candidate?.uuid == targetCharacteristicUuid,
                orElse: () => null,
              );

      if (characteristic == null) {
        _emitStatus('Required notify characteristic was not found.');
        await disconnect(emitStatus: false);
        return;
      }

      _sportCharacteristic = characteristic;
      await characteristic.setNotifyValue(true);

      _notificationSubscription = characteristic.lastValueStream.listen(
        (value) {
          if (value.isEmpty) {
            return;
          }

          final sport = utf8.decode(value).trim();
          if (sport.isNotEmpty) {
            _sportController.add(sport);
          }
        },
        onError: (Object error) {
          _emitStatus('Notification error: $error');
        },
      );

      _connectionController.add(true);
      _emitStatus('Connected. Listening for sport updates.');
    } catch (error) {
      _emitStatus('Service discovery failed: $error');
      await disconnect(emitStatus: false);
    }
  }

  Future<void> disconnect({bool emitStatus = true}) async {
    final device = _connectedDevice;
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {
        // The device may already be disconnected, which is safe to ignore.
      }
    }

    await _resetConnectionState();
    _connectionController.add(false);

    if (emitStatus) {
      _emitStatus('Disconnected.');
    }
  }

  Future<void> dispose() async {
    await disconnect(emitStatus: false);
    await _statusController.close();
    await _sportController.close();
    await _connectionController.close();
  }

  Future<void> _resetConnectionState() async {
    _sportCharacteristic = null;
    _connectedDevice = null;
  }

  void _emitStatus(String message) {
    if (!_statusController.isClosed) {
      _statusController.add(message);
    }
  }
}
