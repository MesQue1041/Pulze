import 'package:flutter/material.dart';

import '../core/model_weights.dart';
import '../core/drift_params.dart';
import '../core/ride_loader.dart';
import '../core/ride_analysis.dart';
import '../core/zones.dart';

import 'widgets/hr_compare_chart.dart';
import 'widgets/drift_line_chart.dart';
import 'widgets/time_in_zone_bar.dart';

class PostRideSummaryScreen extends StatefulWidget {
  final String filePath;
  final int hrMax;
  final List<double> zoneUpperFrac;

  const PostRideSummaryScreen({
    super.key,
    required this.filePath,
    required this.hrMax,
    required this.zoneUpperFrac,
  });

  @override
  State<PostRideSummaryScreen> createState() => _PostRideSummaryScreenState();
}

class _PostRideSummaryScreenState extends State<PostRideSummaryScreen> {
  static const String weightsAsset = 'assets/models/expected_hr_global.json';
  static const String paramsAsset = 'assets/models/drift_params.json';

  bool loading = true;
  String? err;

  RideAnalysisResult? res;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w = await ModelWeights.loadFromAsset(weightsAsset);
      final p = await DriftParams.loadFromAsset(paramsAsset);

      final zones = HrZones(
        hrMax: widget.hrMax.toDouble(),
        zoneUpperFrac: widget.zoneUpperFrac,
      );

      final rows = await RideLoader.loadCsvFile(widget.filePath);
      final r = RideAnalyzer.analyze(rows: rows, weights: w, params: p, zones: zones);

      setState(() {
        res = r;
        loading = false;
      });
    } catch (e) {
      setState(() {
        err = e.toString();
        loading = false;
      });
    }
  }

  String _fmtDur(double sec) {
    final s = sec.round();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post-Ride Summary")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : err != null
          ? Padding(padding: const EdgeInsets.all(16), child: Text("Error: $err"))
          : _body(),
    );
  }

  Widget _body() {
    final r = res!;
    final m = r.metrics;

    final xMin = r.series.map((p) => p.tSec / 60.0).toList(growable: false);
    final obs = r.series.map((p) => p.hrObs).toList(growable: false);
    final eff = r.series.map((p) => p.hrEff).toList(growable: false);
    final drift = r.series.map((p) => p.drift).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text("Ride Overview", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _kv("Duration", _fmtDur(m.durationSec)),
          _kv("Avg HR", "${m.avgHr.toStringAsFixed(0)} bpm"),
          _kv("Max HR", "${m.maxHr.toStringAsFixed(0)} bpm"),

          const Divider(height: 26),

          const Text("Drift / Correction", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _kv("Max drift", "${m.maxDrift.toStringAsFixed(1)} bpm"),
          _kv("End drift", "${m.endDrift.toStringAsFixed(1)} bpm"),
          _kv("Minutes corrected", "${m.minutesCorrected.toStringAsFixed(1)} min"),

          const Divider(height: 26),

          const Text("Observed vs Effective HR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          HrCompareChart(
            xMin: xMin,
            hrObserved: obs,
            hrEffective: eff,
            height: 270,
          ),

          const SizedBox(height: 18),

          DriftLineChart(
            xMin: xMin,
            driftBpm: drift,
            height: 220,
          ),

          const Divider(height: 26),

          const Text("Time in Zone — Raw vs Effective", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          TimeInZoneBarChart(
            rawMin: m.timeInZoneRawMin,
            effMin: m.timeInZoneEffMin,
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(v),
        ],
      ),
    );
  }
}