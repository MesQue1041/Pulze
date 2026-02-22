import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class HrBleDevice {
  final String id;
  final String name;
  HrBleDevice({required this.id, required this.name});
}

class HrBleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // Standard Heart Rate Service + Measurement characteristic
  static final Uuid hrService = Uuid.parse("0000180d-0000-1000-8000-00805f9b34fb");
  static final Uuid hrMeasurementChar = Uuid.parse("00002a37-0000-1000-8000-00805f9b34fb");

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;

  final _devices = <String, HrBleDevice>{};
  final _devicesCtrl = StreamController<List<HrBleDevice>>.broadcast();
  Stream<List<HrBleDevice>> get devicesStream => _devicesCtrl.stream;

  final _hrCtrl = StreamController<int>.broadcast();
  Stream<int> get hrStream => _hrCtrl.stream;

  String? connectedId;

  void startScan({Duration timeout = const Duration(seconds: 6)}) {
    stopScan();
    _devices.clear();
    _devicesCtrl.add([]);

    _scanSub = _ble
        .scanForDevices(withServices: [hrService], scanMode: ScanMode.lowLatency)
        .listen((d) {
      final name = (d.name.isNotEmpty) ? d.name : (d.manufacturerData.isNotEmpty ? "HR Sensor" : "Unknown");
      _devices[d.id] = HrBleDevice(id: d.id, name: name);
      _devicesCtrl.add(_devices.values.toList()..sort((a, b) => a.name.compareTo(b.name)));
    });

    Future.delayed(timeout, () => stopScan());
  }

  void stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
  }

  Future<void> connect(String deviceId) async {
    await disconnect();

    connectedId = deviceId;

    _connSub = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    ).listen((update) async {
      if (update.connectionState == DeviceConnectionState.connected) {
        // subscribe to HR notifications
        final qc = QualifiedCharacteristic(
          serviceId: hrService,
          characteristicId: hrMeasurementChar,
          deviceId: deviceId,
        );

        _notifySub?.cancel();
        _notifySub = _ble.subscribeToCharacteristic(qc).listen((data) {
          final hr = _parseHrMeasurement(data);
          if (hr != null) _hrCtrl.add(hr);
        });
      }

      if (update.connectionState == DeviceConnectionState.disconnected) {
        await _notifySub?.cancel();
        _notifySub = null;
        connectedId = null;
      }
    });
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _connSub?.cancel();
    _connSub = null;
    connectedId = null;
  }

  int? _parseHrMeasurement(List<int> data) {
    if (data.isEmpty) return null;

    final flags = data[0];
    final isUint16 = (flags & 0x01) != 0;

    if (!isUint16) {
      if (data.length < 2) return null;
      return data[1];
    } else {
      if (data.length < 3) return null;
      final v = data[1] | (data[2] << 8);
      return v;
    }
  }

  Future<void> dispose() async {
    stopScan();
    await disconnect();
    await _devicesCtrl.close();
    await _hrCtrl.close();
  }
}
