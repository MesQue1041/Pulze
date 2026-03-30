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
  static const String _weightsAsset = 'assets/models/expected_hr_global.json';
  static const String _paramsAsset  = 'assets/models/drift_params.json';

  bool _loading = true;
  String? _err;
  RideAnalysisResult? _res;
  _RideStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w     = await ModelWeights.loadFromAsset(_weightsAsset);
      final p     = await DriftParams.loadFromAsset(_paramsAsset);
      final zones = HrZones(
        hrMax: widget.hrMax.toDouble(),
        zoneUpperFrac: widget.zoneUpperFrac,
      );
      final rows = await RideLoader.loadCsvFile(widget.filePath);
      final r    = RideAnalyzer.analyze(rows: rows, weights: w, params: p, zones: zones);
      final stats = _RideStats.fromRows(rows);
      setState(() {
        _res     = r;
        _stats   = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _err     = e.toString();
        _loading = false;
      });
    }
  }

  String _fmtDur(double sec) {
    final s  = sec.round();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post-Ride Summary')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $_err', style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    return _body();
  }

  Widget _body() {
    final r    = _res!;
    final m    = r.metrics;
    final st   = _stats!;

    final xMin = r.series.map((p) => p.tSec / 60.0).toList(growable: false);
    final obs  = r.series.map((p) => p.hrObs).toList(growable: false);
    final eff  = r.series.map((p) => p.hrEff).toList(growable: false);
    final drift = r.series.map((p) => p.drift).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Post-Ride Summary')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [

            //Ride Overview
            _sectionHeader('Ride Overview'),
            _kv('Duration',  _fmtDur(m.durationSec)),
            _kv('Avg HR',    '${m.avgHr.toStringAsFixed(0)} bpm'),
            _kv('Max HR',    '${m.maxHr.toStringAsFixed(0)} bpm'),

            const Divider(height: 26),

            // Drift Correction
            _sectionHeader('Drift Correction'),
            _kv('Max drift detected',       '${m.maxDrift.toStringAsFixed(1)} bpm'),
            _kv('End-of-ride drift',        '${m.endDrift.toStringAsFixed(1)} bpm'),
            _kv('Minutes correction active','${m.minutesCorrected.toStringAsFixed(1)} min'),

            const Divider(height: 26),

            // Ride Stats
            _sectionHeader('Ride Stats'),
            _RideStatsCard(stats: st, metrics: m),

            const Divider(height: 26),

            // HR Chart
            _sectionHeader('Observed vs Effective HR'),
            HrCompareChart(
              xMin: xMin,
              hrObserved: obs,
              hrEffective: eff,
              height: 270,
            ),
            const SizedBox(height: 18),

            // Drift Chart
            DriftLineChart(xMin: xMin, driftBpm: drift, height: 220),

            const Divider(height: 26),

            //  Time in Zone
            _sectionHeader('Time in Zone — Raw vs Effective'),
            TimeInZoneBarChart(
              rawMin: m.timeInZoneRawMin,
              effMin: m.timeInZoneEffMin,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(v),
      ],
    ),
  );
}


// Speed / grade / elevation stats  from raw RideRows

class _RideStats {
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double avgGradePct;
  final double maxGradePct;
  final double minGradePct;
  final double elevationGainM;

  const _RideStats({
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.avgGradePct,
    required this.maxGradePct,
    required this.minGradePct,
    required this.elevationGainM,
  });

  factory _RideStats.fromRows(List<dynamic> rows) {
    if (rows.isEmpty) {
      return const _RideStats(
        avgSpeedKmh: 0, maxSpeedKmh: 0,
        avgGradePct: 0, maxGradePct: 0, minGradePct: 0,
        elevationGainM: 0,
      );
    }

    double speedSum = 0, speedMax = 0;
    double gradeSum = 0, gradeMax = -999, gradeMin = 999;
    double elevGain = 0;
    int count = 0;

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final double spd   = (r.speedKmh as double);
      final double grade = (r.grade2m as double) * 100;

      speedSum += spd;
      if (spd > speedMax) speedMax = spd;

      gradeSum += grade;
      if (grade > gradeMax) gradeMax = grade;
      if (grade < gradeMin) gradeMin = grade;


      if (i > 0 && grade > 0) {
        final distM = spd / 3.6 * 5.0;
        elevGain += distM * (grade / 100.0);
      }

      count++;
    }

    return _RideStats(
      avgSpeedKmh:  speedSum / count,
      maxSpeedKmh:  speedMax,
      avgGradePct:  gradeSum / count,
      maxGradePct:  gradeMax == -999 ? 0 : gradeMax,
      minGradePct:  gradeMin == 999  ? 0 : gradeMin,
      elevationGainM: elevGain,
    );
  }
}


// Ride Stats card widget

class _RideStatsCard extends StatelessWidget {
  final _RideStats stats;
  final RideMetrics metrics;

  const _RideStatsCard({required this.stats, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
        color: cs.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Column(
        children: [
          // Speed row
          _groupLabel(context, Icons.speed_rounded, 'Speed'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statTile(context, 'Avg Speed',
                  '${stats.avgSpeedKmh.toStringAsFixed(1)} km/h')),
              const SizedBox(width: 10),
              Expanded(child: _statTile(context, 'Max Speed',
                  '${stats.maxSpeedKmh.toStringAsFixed(1)} km/h')),
            ],
          ),

          const SizedBox(height: 16),

          // Grade row
          _groupLabel(context, Icons.landscape_rounded, 'Grade'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statTile(context, 'Avg Grade',
                  '${stats.avgGradePct.toStringAsFixed(1)}%')),
              const SizedBox(width: 10),
              Expanded(child: _statTile(context, 'Max Climb',
                  '${stats.maxGradePct.toStringAsFixed(1)}%')),
              const SizedBox(width: 10),
              Expanded(child: _statTile(context, 'Max Descent',
                  '${stats.minGradePct.toStringAsFixed(1)}%')),
            ],
          ),

          const SizedBox(height: 16),

          //  Elevation row
          _groupLabel(context, Icons.trending_up_rounded, 'Elevation'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statTile(context, 'Total Gain',
                  '${stats.elevationGainM.toStringAsFixed(0)} m')),
              const SizedBox(width: 10),
              Expanded(child: _statTile(context, 'Avg Power Proxy',
                  '${metrics.avgPUsedRoll60.toStringAsFixed(1)} W')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _groupLabel(BuildContext context, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: cs.primary,
          ),
        ),
      ],
    );
  }

  Widget _statTile(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}