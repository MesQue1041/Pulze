import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../core/model_weights.dart';
import '../core/drift_params.dart';
import '../core/drift_estimator.dart';
import '../core/zones.dart';
import '../core/hr_ble_service.dart';
import '../core/gps_service.dart';
import '../core/feature_builder.dart';
import '../core/ride_storage.dart';
import '../core/ride_recorder.dart';
import 'post_ride_summary_screen.dart';


// Foreground task handler

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_PulzeTaskHandler());
}

class _PulzeTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {

  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}



class LiveRideScreen extends StatefulWidget {
  final int hrMax;
  final List<double> zoneUpperFrac;
  final double weightKg;
  final int driftStartMinOverride;

  const LiveRideScreen({
    super.key,
    required this.hrMax,
    required this.zoneUpperFrac,
    required this.weightKg,
    required this.driftStartMinOverride,
  });

  @override
  State<LiveRideScreen> createState() => _LiveRideScreenState();
}

class _LiveRideScreenState extends State<LiveRideScreen> {
  static const String _weightsAsset = 'assets/models/expected_hr_global.json';
  static const String _paramsAsset = 'assets/models/drift_params.json';

  final HrBleService _hrBle = HrBleService();
  final GpsService _gps = GpsService();
  late FeatureBuilder _fb;

  DriftParams? _params;
  DriftEstimator? _drift;
  DriftState _driftState = DriftState();
  late HrZones _zones;
  bool _modelsReady = false;

  StreamSubscription<int>? _hrSub;
  StreamSubscription<GpsSample>? _gpsSub;
  StreamSubscription<List<HrBleDevice>>? _scanSub;
  StreamSubscription<DeviceConnectionState>? _connStateSub;

  bool _connected = false;
  bool _riding = false;
  bool _paused = false;
  bool _dualView = false;
  bool _stopping = false;

  // HR state
  int _hrObs = 0;
  double _hrEff = 0.0;
  int _zEff = 1;
  int _zObs = 1;
  double _driftBpm = 0.0;
  bool _corrActive = false;

  // Latest GPS features
  LiveFeatures? _latestFeatures;
  double _speedKmh = 0.0;
  double _distanceM = 0.0;
  GpsSample? _lastGpsForDist;

  final Stopwatch _sw = Stopwatch();
  Timer? _uiTimer;
  String _elapsedStr = '00:00:00';

  final RideRecorder _recorder = RideRecorder();
  String? _rideFilePath;

  List<HrBleDevice> _scanResults = [];

  // Foreground service init

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pulze_ride',
        channelName: 'Pulze Ride',
        channelDescription: 'Active while a ride is being recorded.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _startForegroundService() async {

    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
    await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: 'Pulze — Ride in progress',
      notificationText: 'Recording HR & GPS. Tap to return.',
      callback: startForegroundCallback,
    );
  }

  Future<void> _stopForegroundService() async {
    await FlutterForegroundTask.stopService();
  }

  // Model init

  DriftParams _applyDriftStartOverride(DriftParams p, int overrideMin) {
    return DriftParams(
      resampleSeconds: p.resampleSeconds,
      ewmaAlpha: p.ewmaAlpha,
      driftClipBpm: p.driftClipBpm,
      posResidThresh: p.posResidThresh,
      posPersistSec: p.posPersistSec,
      pStdMax60s: p.pStdMax60s,
      pJumpMax5s: p.pJumpMax5s,
      pMinActive: p.pMinActive,
      speedMinActive: p.speedMinActive,
      driftDecay: p.driftDecay,
      baselineMin: p.baselineMin,
      minSteadyPowerSec: p.minSteadyPowerSec,
      minSteadyForDriftSec: p.minSteadyForDriftSec,
      calibMinSession: p.calibMinSession,
      debounceOnSec: p.debounceOnSec,
      debounceOffSec: p.debounceOffSec,
      holdGapSec: p.holdGapSec,
      minCalibSamples: p.minCalibSamples,
      sessionOffsetClampBpm: p.sessionOffsetClampBpm,
      driftStartMin: overrideMin,
      driftMaxChangeBpmPerMin: p.driftMaxChangeBpmPerMin,
    );
  }

  String _fmtHms(int sec) {
    final h = (sec ~/ 3600).toString().padLeft(2, '0');
    final m = ((sec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _initModels() async {
    _fb = FeatureBuilder(weightKg: widget.weightKg);
    _zones = HrZones(
      hrMax: widget.hrMax.toDouble(),
      zoneUpperFrac: widget.zoneUpperFrac,
    );
    final w = await ModelWeights.loadFromAsset(_weightsAsset);
    final p0 = await DriftParams.loadFromAsset(_paramsAsset);
    final p = _applyDriftStartOverride(p0, widget.driftStartMinOverride);
    if (!mounted) return;
    setState(() {
      _params = p;
      _drift = DriftEstimator(weights: w, p: p);
      _driftState = DriftState();
      _modelsReady = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _initModels();
    _initForegroundTask();

    // BLE connection state
    _connStateSub = _hrBle.connectionStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _connected = state == DeviceConnectionState.connected;
        if (!_connected) {
          _hrObs = 0;
          if (!_riding) {
            _hrEff = 0.0;
            _zEff = 1;
            _zObs = 1;
          }
        }
      });
    });

    // BLE HR listener

    _hrSub = _hrBle.hrStream.listen((v) {
      if (!mounted) return;

      if (!_riding) {
        setState(() {
          _hrObs = v;
          _zObs = _zones.zoneOf(v.toDouble());
          _hrEff = v.toDouble();
          _zEff = _zones.zoneOf(v.toDouble());
        });
        return;
      }

      if (_paused) return;

      final feats = _latestFeatures;
      final p = _params;
      final d = _drift;

      if (feats == null || p == null || d == null) {
        setState(() {
          _hrObs = v;
          _zObs = _zones.zoneOf(v.toDouble());
          _hrEff = v.toDouble();
          _zEff = _zones.zoneOf(v.toDouble());
        });
        return;
      }

      //  drift estimator
      final out = d.update(
        state: _driftState,
        elapsedSeconds: feats.tSec,
        hr: v.toDouble(),
        pUsed: feats.pUsed,
        pUsedRoll60: feats.pUsedRoll60,
        speedKmh: feats.speedKmhClean,
        gradeRoll2m: feats.gradeRoll2m,
        steadyRaw: feats.steadyRaw,
      );

      final expectedAdj = (out['expectedAdj'] as double?) ?? v.toDouble();
      final eff = (out['hrEffective'] as double?) ?? v.toDouble();
      final dBpm = (out['drift'] as double?) ?? 0.0;
      final corr = (out['corrActive'] as bool?) ?? false;
      final driftAllowed = (out['driftAllowed'] as bool?) ?? false;
      final steadyOk = (out['steadyOk'] as bool?) ?? false;
      final effUse = (eff.isFinite && eff > 0) ? eff : v.toDouble();

      setState(() {
        _hrObs = v;
        _hrEff = effUse;
        _zObs = _zones.zoneOf(v.toDouble());
        _zEff = _zones.zoneOf(effUse);
        _driftBpm = dBpm;
        _corrActive = corr;
      });

      // Write CSV row at BLE speed
      if (_recorder.isRecording) {
        _recorder.writeRow(
          elapsedSec: feats.tSec,
          hr: v,
          pUsed: feats.pUsed,
          pUsedRoll60: feats.pUsedRoll60,
          speedKmhClean: feats.speedKmhClean,
          gradeRoll2m: feats.gradeRoll2m,
          corrActive: corr ? 1 : 0,
          expectedHr: expectedAdj,
          effectiveHr: effUse,
          drift: dBpm,
          rawZone: _zones.zoneOf(v.toDouble()),
          effectiveZone: _zones.zoneOf(effUse),
          steadyOk: steadyOk,
          driftAllowed: driftAllowed,
        );
      }
    }, onError: (e) => print('UI hrStream error: $e'));
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _hrSub?.cancel();
    _gpsSub?.cancel();
    _scanSub?.cancel();
    _connStateSub?.cancel();
    _hrBle.dispose();
    _gps.dispose();
    super.dispose();
  }

  void _startScan() {
    _scanResults = [];
    _scanSub?.cancel();
    _scanSub = _hrBle.devicesStream.listen((list) {
      if (!mounted) return;
      setState(() => _scanResults = list);
    });
    _hrBle.startScan();
  }

  Future<void> _connectTo(HrBleDevice d) async {
    await _hrBle.connect(d.id);
  }

  double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    double deg2rad(double d) => d * pi / 180.0;
    final dLat = deg2rad(lat2 - lat1);
    final dLon = deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(deg2rad(lat1)) * cos(deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  Future<void> _startRide() async {
    if (!_modelsReady || _params == null || _drift == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Models still loading, please wait...')),
      );
      return;
    }
    if (!_connected || _hrObs <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No live HR yet. Connect strap and wait for BPM.')),
      );
      return;
    }
    final ok = await _gps.ensureReady();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('GPS not ready. Enable location permissions/services.')),
      );
      return;
    }

    setState(() {
      _riding = true;
      _paused = false;
      _stopping = false;
      _hrEff = _hrObs.toDouble();
      _driftBpm = 0.0;
      _corrActive = false;
      _speedKmh = 0.0;
      _distanceM = 0.0;
      _lastGpsForDist = null;
      _latestFeatures = null;
      _driftState = DriftState();
      _zEff = _zones.zoneOf(_hrEff);
      _zObs = _zones.zoneOf(_hrObs.toDouble());
    });

    final f = await RideStorage.createNewRideFile();
    _rideFilePath = f.path;
    await _recorder.start(f);

    _sw
      ..reset()
      ..start();

    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _elapsedStr = _fmtHms(_sw.elapsed.inSeconds));
    });


    await _startForegroundService();
    await _gps.start();


    _gpsSub?.cancel();
    _gpsSub = _gps.stream.listen((s) {
      if (!_riding || _paused) return;

      final prev = _lastGpsForDist;
      if (prev != null) {
        final d = _haversineM(prev.lat, prev.lon, s.lat, s.lon);
        if (d.isFinite && d >= 0 && d < 200) _distanceM += d;
      }
      _lastGpsForDist = s;

      final feats = _fb.updateFromGps(s);
      _latestFeatures = feats;

      if (mounted) setState(() => _speedKmh = feats.speedKmhClean);
    });
  }

  Future<void> _pauseResume() async {
    if (!_riding) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _sw.stop();
    } else {
      _sw.start();
    }
  }

  Future<void> _stopRide() async {
    if (!_riding || _stopping) return;
    _stopping = true;

    setState(() {
      _riding = false;
      _paused = false;
    });

    _sw.stop();
    _uiTimer?.cancel();
    _uiTimer = null;

    _gpsSub?.cancel();
    _gpsSub = null;

    await _recorder.stop();
    _gps.stop();
    await _stopForegroundService();

    final path = _rideFilePath;
    if (!mounted || path == null) {
      _stopping = false;
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PostRideSummaryScreen(
          filePath: path,
          hrMax: widget.hrMax,
          zoneUpperFrac: widget.zoneUpperFrac,
        ),
      ),
    );
  }

  // UI

  static const _zoneColors = [
    Color(0xFF5BC8F5),
    Color(0xFF81C784),
    Color(0xFFFFD54F),
    Color(0xFFFF8C55),
    Color(0xFFEF5350),
  ];

  Color _zoneColor(int zone) =>
      _zoneColors[(zone - 1).clamp(0, _zoneColors.length - 1)];

  @override
  Widget build(BuildContext context) {
    final distKm = _distanceM / 1000.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Ride'),
        actions: [
          if (_connected)
            IconButton(
              tooltip: _dualView ? 'Single view' : 'Dual view',
              icon: Icon(_dualView ? Icons.filter_1 : Icons.filter_2),
              onPressed: () => setState(() => _dualView = !_dualView),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _elapsedStr,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900),
                ),
                Row(
                  children: [
                    Icon(_connected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled),
                    const SizedBox(width: 6),
                    Text(_connected ? 'Connected' : 'Not connected'),
                    const SizedBox(width: 10),
                    if (_corrActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                        ),
                        child: const Text('Correction active',
                            style:
                            TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // HR circle
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: _dualView ? _dualCircle() : _singleCircle(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _zoneTile(context),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _metricTile(context,
                      label: 'Speed (km/h)',
                      value: _speedKmh.isFinite
                          ? _speedKmh.toStringAsFixed(1)
                          : '0.0',
                      icon: Icons.speed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricTile(context,
                      label: 'Distance (km)',
                      value: distKm.isFinite
                          ? distKm.toStringAsFixed(2)
                          : '0.00',
                      icon: Icons.route),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Drift tile
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Drift estimate',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ),
                  Text('${_driftBpm.toStringAsFixed(1)} bpm',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Buttons
            if (!_connected && !_riding) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Scan HR Devices'),
                  onPressed: _startScan,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(flex: 0, child: _deviceList()),
              const SizedBox(height: 10),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: Icon(_riding
                            ? (_paused
                            ? Icons.play_arrow
                            : Icons.pause)
                            : Icons.fiber_manual_record),
                        label: Text(_riding
                            ? (_paused ? 'Resume' : 'Pause')
                            : 'Start'),
                        onPressed: _riding ? _pauseResume : _startRide,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                        onPressed: (_riding && !_stopping) ? _stopRide : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _singleCircle() {
    final display = _hrEff.isFinite && _hrEff > 0
        ? _hrEff.toStringAsFixed(0)
        : (_hrObs > 0 ? _hrObs.toString() : '--');
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(display,
            style:
            const TextStyle(fontSize: 74, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        const Text('bpm',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888),
                letterSpacing: 1)),
        const SizedBox(height: 6),
        const Text('Effective HR',
            style: TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Widget _dualCircle() {
    final rawStr = _hrObs > 0 ? _hrObs.toString() : '--';
    final effStr = _hrEff.isFinite && _hrEff > 0
        ? _hrEff.toStringAsFixed(0)
        : rawStr;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Raw / Effective',
            style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 10),
        Text('$rawStr  |  $effStr',
            style:
            const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text('bpm',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888),
                letterSpacing: 1)),
      ],
    );
  }

  Widget _zoneTile(BuildContext context) {
    if (_dualView) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.favorite, color: _zoneColor(_zEff)),
            const SizedBox(width: 10),
            Text('Zones',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Raw: Zone $_zObs',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Effective: Zone $_zEff',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: Color(0xFFFF8C55))),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite, color: _zoneColor(_zEff)),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Zone',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant))),
          Text('Zone $_zEff',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _deviceList() {
    if (_scanResults.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _scanResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final d = _scanResults[i];
          return ListTile(
            title: Text(d.name),
            subtitle: Text(d.id),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _connectTo(d),
          );
        },
      ),
    );
  }

  Widget _metricTile(BuildContext context,
      {required String label,
        required String value,
        required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                Text(value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}