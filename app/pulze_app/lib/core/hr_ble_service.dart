import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class HrBleDevice {
  final String id;
  final String name;

  HrBleDevice({required this.id, required this.name});
}

class HrBleService {
  final FlutterReactiveBle ble = FlutterReactiveBle();

  static final Uuid hrService =
  Uuid.parse('0000180d-0000-1000-8000-00805f9b34fb');
  static final Uuid hrMeasurementChar =
  Uuid.parse('00002a37-0000-1000-8000-00805f9b34fb');

  StreamSubscription<DiscoveredDevice>? scanSub;
  StreamSubscription<ConnectionStateUpdate>? connSub;
  StreamSubscription<List<int>>? notifySub;

  final Map<String, HrBleDevice> devices = {};
  final devicesCtrl = StreamController<List<HrBleDevice>>.broadcast();
  Stream<List<HrBleDevice>> get devicesStream => devicesCtrl.stream;


  final hrCtrl = StreamController<int>.broadcast();
  Stream<int> get hrStream => hrCtrl.stream;

  final connStateCtrl = StreamController<DeviceConnectionState>.broadcast();
  Stream<DeviceConnectionState> get connectionStateStream =>
      connStateCtrl.stream;

  String? connectedId;
  bool scanning = false;

  // Track last successfully parsed HR value so callers can read it directly
  int? lastHr;

  void startScan({Duration timeout = const Duration(seconds: 6)}) {
    stopScan();
    devices.clear();
    devicesCtrl.add([]);

    scanning = true;
    scanSub = ble
        .scanForDevices(
      withServices: [hrService],
      scanMode: ScanMode.lowLatency,
    )
        .listen(
          (d) {
        final name = d.name.isNotEmpty
            ? d.name
            : (d.manufacturerData.isNotEmpty
            ? 'HR Sensor'
            : 'Unknown HR Sensor');
        devices[d.id] = HrBleDevice(id: d.id, name: name);
        devicesCtrl.add(
          devices.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
        );
      },
      onError: (e) => print('BLE scan error: $e'),
    );

    Future.delayed(timeout, stopScan);
  }

  void stopScan() {
    scanning = false;
    scanSub?.cancel();
    scanSub = null;
  }

  Future<void> connect(String deviceId) async {
    await disconnect();
    stopScan();

    connectedId = deviceId;
    print('BLE connect requested: $deviceId');

    connSub = ble
        .connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 15),
    )
        .listen(
          (update) async {
        print('BLE connection state: ${update.connectionState}');
        connStateCtrl.add(update.connectionState);

        if (update.connectionState == DeviceConnectionState.connected) {
          final qc = QualifiedCharacteristic(
            serviceId: hrService,
            characteristicId: hrMeasurementChar,
            deviceId: deviceId,
          );

          await notifySub?.cancel();
          notifySub = ble.subscribeToCharacteristic(qc).listen(
                (data) {
              final hr = parseHrMeasurement(data);
              if (hr != null && hr > 0) {
                lastHr = hr;
                if (!hrCtrl.isClosed) hrCtrl.add(hr);
              }
            },
            onError: (e) {
              print('BLE notify error: $e');

            },
            cancelOnError: false,
          );
        }

        if (update.connectionState == DeviceConnectionState.disconnected) {
          print('BLE disconnected');
          await notifySub?.cancel();
          notifySub = null;
          connectedId = null;
          lastHr = null;
        }
      },
      onError: (e) async {
        print('BLE connection error: $e');
        await notifySub?.cancel();
        notifySub = null;
        connectedId = null;
        lastHr = null;
        if (!connStateCtrl.isClosed) {
          connStateCtrl.add(DeviceConnectionState.disconnected);
        }
      },
    );
  }

  Future<void> disconnect() async {
    await notifySub?.cancel();
    notifySub = null;
    await connSub?.cancel();
    connSub = null;
    connectedId = null;
    lastHr = null;
  }

  int? parseHrMeasurement(List<int> data) {
    if (data.isEmpty) return null;
    final flags = data[0];
    final isUint16 = (flags & 0x01) != 0;
    if (!isUint16) {
      if (data.length < 2) return null;
      return data[1];
    } else {
      if (data.length < 3) return null;
      return data[1] | (data[2] << 8);
    }
  }

  Future<void> dispose() async {
    stopScan();
    await disconnect();
    if (!devicesCtrl.isClosed) await devicesCtrl.close();
    if (!hrCtrl.isClosed) await hrCtrl.close();
    if (!connStateCtrl.isClosed) await connStateCtrl.close();
  }
}