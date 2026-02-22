import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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
  static const String weightsAsset = 'assets/models/expected_hr_global.json';
  static const String paramsAsset = 'assets/models/drift_params.json';

  final HrBleService hrBle = HrBleService();
  final GpsService gps = GpsService();
  late FeatureBuilder fb;

  DriftParams? params;
  DriftEstimator? drift;
  DriftState driftState = DriftState();
  late HrZones zones;

  StreamSubscription<int>? _hrSub;
  StreamSubscription<GpsSample>? _gpsSub;

  // Ride state
  bool connected = false;
  bool riding = false;
  bool paused = false;

  // UI mode: single = effective only and dual = raw + effective
  bool dualView = false;

  int hrObs = 0;
  double hrEff = 0.0;
  int zEff = 1;
  int zObs = 1;
  double driftBpm = 0.0;
  bool corrActive = false;

  // GPS / metrics
  double speedKmh = 0.0;
  double distanceM = 0.0;
  GpsSample? _lastGpsForDist;

  // Timer / elapsed
  final Stopwatch _sw = Stopwatch();
  Timer? _uiTimer;
  String elapsedStr = "00:00:00";

  // Recorder
  final RideRecorder recorder = RideRecorder();
  String? rideFilePath;

  // Device scan
  List<HrBleDevice> scanResults = [];
  StreamSubscription<List<HrBleDevice>>? _scanSub;

  DriftParams _withDriftStartOverride(DriftParams p, int driftStartMinOverride) {
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
      driftStartMin: driftStartMinOverride,
      driftMaxChangeBpmPerMin: p.driftMaxChangeBpmPerMin,
    );
  }

  String _fmtHms(int sec) {
    final h = (sec ~/ 3600).toString().padLeft(2, '0');
    final m = ((sec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  Future<void> _initModels() async {
    fb = FeatureBuilder(weightKg: widget.weightKg);
    zones = HrZones(
      hrMax: widget.hrMax.toDouble(),
      zoneUpperFrac: widget.zoneUpperFrac,
    );

    final w = await ModelWeights.loadFromAsset(weightsAsset);
    final p0 = await DriftParams.loadFromAsset(paramsAsset);
    final p = _withDriftStartOverride(p0, widget.driftStartMinOverride);

    if (!mounted) return;
    setState(() {
      params = p;
      drift = DriftEstimator(weights: w, p: p);
      driftState = DriftState();
    });
  }

  @override
  void initState() {
    super.initState();
    _initModels();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _hrSub?.cancel();
    _gpsSub?.cancel();
    _scanSub?.cancel();
    hrBle.dispose();
    gps.dispose();
    super.dispose();
  }

  void _startScan() {
    scanResults = [];
    _scanSub?.cancel();
    _scanSub = hrBle.devicesStream.listen((list) {
      if (!mounted) return;
      setState(() => scanResults = list);
    });
    hrBle.startScan();
  }

  Future<void> _connectTo(HrBleDevice d) async {
    try {
      await hrBle.connect(d.id);
      if (!mounted) return;
      setState(() => connected = true);

      _hrSub?.cancel();
      _hrSub = hrBle.hrStream.listen((v) {
        if (!mounted) return;
        setState(() {
          hrObs = v;
          zObs = zones.zoneOf(hrObs.toDouble());
          if (!riding) {
            hrEff = hrObs.toDouble();
            zEff = zones.zoneOf(hrEff);
          }
        });
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => connected = false);
    }
  }

  double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    double deg2rad(double d) => d * pi / 180.0;
    final dLat = deg2rad(lat2 - lat1);
    final dLon = deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(deg2rad(lat1)) * cos(deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> _startRide() async {
    if (params == null || drift == null) return;

    final ok = await gps.ensureReady();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("GPS not ready. Please enable location permissions/services.")),
      );
      return;
    }

    setState(() {
      riding = true;
      paused = false;
      hrEff = hrObs.toDouble();
      driftBpm = 0.0;
      corrActive = false;
      speedKmh = 0.0;
      distanceM = 0.0;
      _lastGpsForDist = null;
      driftState = DriftState();
      zEff = zones.zoneOf(hrEff);
      zObs = zones.zoneOf(hrObs.toDouble());
    });

    final f = await RideStorage.createNewRideFile();
    rideFilePath = f.path;
    await recorder.start(f);

    _sw
      ..reset()
      ..start();

    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => elapsedStr = _fmtHms(_sw.elapsed.inSeconds));
    });

    await gps.start();

    _gpsSub?.cancel();
    _gpsSub = gps.stream.listen((s) {
      if (!riding || paused || params == null || drift == null) return;

      if (_lastGpsForDist != null) {
        final d = _haversineM(_lastGpsForDist!.lat, _lastGpsForDist!.lon, s.lat, s.lon);
        if (d.isFinite && d >= 0 && d < 200) {
          distanceM += d;
        }
      }
      _lastGpsForDist = s;

      final feats = fb.updateFromGps(s);
      speedKmh = feats.speedKmhClean;

      final out = drift!.update(
        state: driftState,
        elapsedSeconds: feats.tSec,
        hr: hrObs.toDouble(),
        pUsed: feats.pUsed,
        pUsedRoll60: feats.pUsedRoll60,
        speedKmh: feats.speedKmhClean,
        gradeRoll2m: feats.gradeRoll2m,
        steadyRaw: feats.steadyRaw,
      );

      final eff = (out["hrEffective"] as double?) ?? hrObs.toDouble();
      final dBpm = (out["drift"] as double?) ?? 0.0;
      final corr = (out["corrActive"] as bool?) ?? false;

      final effUse = (eff.isFinite && eff > 0) ? eff : hrObs.toDouble();

      recorder.writeRow(
        elapsedSec: feats.tSec,
        hr: hrObs,
        pUsed: feats.pUsed,
        pUsedRoll60: feats.pUsedRoll60,
        speedKmhClean: feats.speedKmhClean,
        gradeRoll2m: feats.gradeRoll2m,
        corrActive: corr ? 1 : 0,
      );

      if (!mounted) return;
      setState(() {
        hrEff = effUse;
        zEff = zones.zoneOf(hrEff);
        zObs = zones.zoneOf(hrObs.toDouble());
        driftBpm = dBpm;
        corrActive = corr;
      });
    });
  }

  Future<void> _pauseResume() async {
    if (!riding) return;
    setState(() => paused = !paused);
    if (paused) {
      _sw.stop();
    } else {
      _sw.start();
    }
  }

  Future<void> _stopRide() async {
    if (!riding) return;

    setState(() {
      riding = false;
      paused = false;
    });

    _sw.stop();
    _uiTimer?.cancel();
    _uiTimer = null;

    await recorder.stop();
    gps.stop();

    final path = rideFilePath;
    if (!mounted || path == null) return;

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

  @override
  Widget build(BuildContext context) {
    final distKm = distanceM / 1000.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Ride"),
        actions: [
          if (connected)
            IconButton(
              tooltip: dualView ? "Single view" : "Dual view",
              icon: Icon(dualView ? Icons.filter_1 : Icons.filter_2),
              onPressed: () => setState(() => dualView = !dualView),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // TOP: elapsed + status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(elapsedStr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Row(
                  children: [
                    Icon(connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
                    const SizedBox(width: 6),
                    Text(connected ? "Connected" : "Not connected"),
                    const SizedBox(width: 10),
                    if (corrActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                        child: const Text("Correction active", style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // HR CIRCLE
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
                    child: dualView ? _dualCircle() : _singleCircle(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ZONE TILE
            _zoneTile(context),

            const SizedBox(height: 12),

            // Speed + Distance tiles
            Row(
              children: [
                Expanded(
                  child: _metricTile(
                    context,
                    label: "Speed (km/h)",
                    value: speedKmh.isFinite ? speedKmh.toStringAsFixed(1) : "0.0",
                    icon: Icons.speed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricTile(
                    context,
                    label: "Distance (km)",
                    value: distKm.isFinite ? distKm.toStringAsFixed(2) : "0.00",
                    icon: Icons.route,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Drift box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Drift estimate",
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    "${driftBpm.toStringAsFixed(1)} bpm",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Controls
            if (!connected && !riding) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text("Scan HR Devices"),
                  onPressed: _startScan,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                flex: 0,
                child: _deviceList(),
              ),
              const SizedBox(height: 10),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: Icon(riding ? (paused ? Icons.play_arrow : Icons.pause) : Icons.fiber_manual_record),
                        label: Text(riding ? (paused ? "Resume" : "Pause") : "Start"),
                        onPressed: riding ? _pauseResume : _startRide,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.stop),
                        label: const Text("Stop"),
                        onPressed: riding ? _stopRide : null,
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          hrEff.isFinite ? hrEff.toStringAsFixed(0) : "--",
          style: const TextStyle(fontSize: 74, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text("Effective HR", style: TextStyle(fontSize: 16, color: Colors.grey)),
      ],
    );
  }

  Widget _dualCircle() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Raw / Effective", style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 10),
        Text(
          "${hrObs > 0 ? hrObs.toString() : "--"}  |  ${hrEff.isFinite ? hrEff.toStringAsFixed(0) : "--"}",
          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text("bpm", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _zoneTile(BuildContext context) {
    String label;
    String value;

    if (!dualView) {
      label = "Zone";
      value = "Zone $zEff";
    } else {
      label = "Zones";
      value = "Raw: Zone $zObs   •   Effective: Zone $zEff";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _deviceList() {
    if (scanResults.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: scanResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final d = scanResults[i];
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

  Widget _metricTile(
      BuildContext context, {
        required String label,
        required String value,
        required IconData icon,
      }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}