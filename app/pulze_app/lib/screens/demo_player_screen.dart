import 'dart:async';
import 'package:flutter/material.dart';

import '../core/model_weights.dart';
import '../core/drift_params.dart';
import '../core/drift_estimator.dart';
import '../core/zones.dart';
import '../core/ride_loader.dart';
import '../core/ride_row.dart';

class DemoPlayerScreen extends StatefulWidget {
  final int hrMax;
  final List<double> zoneUpperFrac;
  final double weightKg;
  final int driftStartMinOverride;

  final String? rideFilePath;

  const DemoPlayerScreen({
    super.key,
    required this.hrMax,
    required this.zoneUpperFrac,
    required this.weightKg,
    required this.driftStartMinOverride,
    this.rideFilePath,
  });

  @override
  State<DemoPlayerScreen> createState() => _DemoPlayerScreenState();
}

class _DemoPlayerScreenState extends State<DemoPlayerScreen> {
  static const String weightsAsset = 'assets/models/expected_hr_global.json';
  static const String paramsAsset = 'assets/models/drift_params.json';
  static const String demoCsvAsset = 'assets/models/demo_ride.csv';

  List<RideRow> ride = [];

  DriftParams? params;
  DriftEstimator? drift;
  DriftState driftState = DriftState();
  late HrZones zones;

  Timer? timer;
  int i = 0;

  // speed control
  bool speed2x = false;
  int get _tickMs => speed2x ? 100 : 200;

  double hr = 0, driftBpm = 0, hrEff = 0;
  int zRaw = 1, zEff = 1;
  bool playing = false;
  bool corrActive = false;

  String elapsedStr = "00:00";
  double elapsedMin = 0.0;

  String? loadError;

  String _fmtTime(double sec) {
    final s = sec.round();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

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

  Future<void> _init() async {
    try {
      final weights = await ModelWeights.loadFromAsset(weightsAsset);
      final pRaw = await DriftParams.loadFromAsset(paramsAsset);
      final p = _withDriftStartOverride(pRaw, widget.driftStartMinOverride);

      final rideRows = (widget.rideFilePath != null)
          ? await RideLoader.loadCsvFile(widget.rideFilePath!)
          : await RideLoader.loadDemoCsv(demoCsvAsset);

      if (!mounted) return;
      setState(() {
        params = p;
        drift = DriftEstimator(weights: weights, p: p);
        driftState = DriftState();
        zones = HrZones(
          hrMax: widget.hrMax.toDouble(),
          zoneUpperFrac: widget.zoneUpperFrac,
        );
        ride = rideRows;

        i = 0;
        hr = driftBpm = hrEff = 0;
        zRaw = zEff = 1;
        playing = false;
        corrActive = false;
        elapsedStr = "00:00";
        elapsedMin = 0.0;
        loadError = null;
      });

      // compute initial frame
      _seekToIndex(0);
    } catch (e) {
      if (!mounted) return;
      setState(() => loadError = e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    zones = HrZones(
      hrMax: widget.hrMax.toDouble(),
      zoneUpperFrac: widget.zoneUpperFrac,
    );
    _init();
  }

  void _start() {
    if (drift == null || params == null || ride.isEmpty) return;
    if (playing) return;

    setState(() => playing = true);

    timer = Timer.periodic(Duration(milliseconds: _tickMs), (_) {
      if (i >= ride.length) {
        _stop();
        return;
      }
      _stepOne();
    });
  }

  void _stepOne() {
    if (drift == null || params == null || i >= ride.length) return;

    final r = ride[i];

    final out = drift!.update(
      state: driftState,
      elapsedSeconds: r.tSec,
      hr: r.hr,
      pUsed: r.pUsed,
      pUsedRoll60: r.pUsed60,
      speedKmh: r.speedKmh,
      gradeRoll2m: r.grade2m,
      steadyRaw: r.corrActive == 1,
      demoMode: true,
      demoCorrMask: r.corrActive == 1,
    );

    final eff = (out["hrEffective"] as double?) ?? r.hr;
    final corr = (out["corrActive"] as bool?) ?? false;

    if (!mounted) return;
    setState(() {
      hr = r.hr;
      driftBpm = (out["drift"] as double?) ?? 0.0;
      hrEff = (eff.isFinite && eff > 0) ? eff : r.hr;

      corrActive = corr;

      zRaw = zones.zoneOf(hr);
      zEff = zones.zoneOf(hrEff);

      elapsedStr = _fmtTime(r.tSec);
      elapsedMin = r.tSec / 60.0;

      i += 1;
    });
  }

  void _stop() {
    timer?.cancel();
    timer = null;
    setState(() => playing = false);
  }

  void _reset() {
    _stop();
    _seekToIndex(0);
  }

  void _seekToIndex(int target) {
    if (drift == null || params == null || ride.isEmpty) return;
    final t = target.clamp(0, ride.length - 1);

    // reset estimator state then replay quickly up to t
    driftState = DriftState();
    int idx = 0;

    double lastHr = 0;
    double lastEff = 0;
    double lastDrift = 0;
    bool lastCorr = false;
    int lastZr = 1;
    int lastZe = 1;
    String lastElapsed = "00:00";
    double lastElapsedMin = 0;

    while (idx <= t) {
      final r = ride[idx];
      final out = drift!.update(
        state: driftState,
        elapsedSeconds: r.tSec,
        hr: r.hr,
        pUsed: r.pUsed,
        pUsedRoll60: r.pUsed60,
        speedKmh: r.speedKmh,
        gradeRoll2m: r.grade2m,
        steadyRaw: r.corrActive == 1,
        demoMode: true,
        demoCorrMask: r.corrActive == 1,
      );

      final eff = (out["hrEffective"] as double?) ?? r.hr;

      lastHr = r.hr;
      lastEff = (eff.isFinite && eff > 0) ? eff : r.hr;
      lastDrift = (out["drift"] as double?) ?? 0.0;
      lastCorr = (out["corrActive"] as bool?) ?? false;

      lastZr = zones.zoneOf(lastHr);
      lastZe = zones.zoneOf(lastEff);

      lastElapsed = _fmtTime(r.tSec);
      lastElapsedMin = r.tSec / 60.0;

      idx += 1;
    }

    setState(() {
      i = t;
      hr = lastHr;
      hrEff = lastEff;
      driftBpm = lastDrift;
      corrActive = lastCorr;
      zRaw = lastZr;
      zEff = lastZe;
      elapsedStr = lastElapsed;
      elapsedMin = lastElapsedMin;
    });
  }

  void _jumpToDriftStart() {
    if (params == null || ride.isEmpty) return;
    final sec = params!.driftStartSec.toDouble();
    int idx = 0;
    while (idx < ride.length && ride[idx].tSec < sec) {
      idx++;
    }
    _seekToIndex(idx);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget _pill(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = drift != null && params != null && ride.isNotEmpty && loadError == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rideFilePath != null ? "Replay Ride" : "Demo Ride Player"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loadError != null
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Failed to load ride:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(loadError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _init, child: const Text('Retry')),
          ],
        )
            : (!ready)
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Elapsed $elapsedStr', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Row(
                  children: [
                    if (corrActive) _pill("Correction active", icon: Icons.auto_fix_high),
                    const SizedBox(width: 8),
                    _pill(speed2x ? "2×" : "1×", icon: Icons.speed),
                  ],
                )
              ],
            ),
            const SizedBox(height: 14),

            // Big HR circle (Effective)
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          hrEff.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text("Effective HR • Z$zEff", style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 14),
                        Text("Observed: ${hr.toStringAsFixed(0)} • Z$zRaw",
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Text("Drift: ${driftBpm.toStringAsFixed(1)} bpm",
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Scrubber
            Row(
              children: [
                Text("${elapsedMin.toStringAsFixed(1)} min", style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: i.toDouble().clamp(0, (ride.length - 1).toDouble()),
                    min: 0,
                    max: (ride.length - 1).toDouble(),
                    onChanged: (v) {
                      // pause while scrubbing
                      if (playing) _stop();
                      _seekToIndex(v.round());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text("${i.clamp(0, ride.length)} / ${ride.length}", style: const TextStyle(color: Colors.grey)),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: playing ? null : _start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Play"),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: playing ? _stop : null,
                      icon: const Icon(Icons.pause),
                      label: const Text("Pause"),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => speed2x = !speed2x);
                        if (playing) {
                          _stop();
                          _start();
                        }
                      },
                      icon: const Icon(Icons.speed),
                      label: Text(speed2x ? "Set 1×" : "Set 2×"),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _jumpToDriftStart,
                      icon: const Icon(Icons.skip_next),
                      label: Text("Jump to ${params!.driftStartMin} min"),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Reset"),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}