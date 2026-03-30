import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/model_weights.dart';
import '../core/drift_params.dart';
import '../core/ride_loader.dart';
import '../core/ride_analysis.dart';
import '../core/ride_storage.dart';
import '../core/zones.dart';

import 'widgets/hr_compare_chart.dart';
import 'widgets/drift_line_chart.dart';
import 'widgets/time_in_zone_bar.dart';

class RideDetailsScreen extends StatefulWidget {
  final String filePath;
  final int hrMax;
  final List<double> zoneUpperFrac;

  const RideDetailsScreen({
    super.key,
    required this.filePath,
    required this.hrMax,
    required this.zoneUpperFrac,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  static const String _weightsAsset = 'assets/models/expected_hr_global.json';
  static const String _paramsAsset  = 'assets/models/drift_params.json';

  bool _loading = true;
  String? _err;
  RideAnalysisResult? _res;
  _RideStats? _stats;

  // Comparison data  up to 3 other rides
  List<_CompareEntry> _compareEntries = [];
  bool _compareLoading = false;
  bool _compareExpanded = false;

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

  Future<void> _loadComparison() async {
    if (_compareLoading) return;
    setState(() => _compareLoading = true);

    try {
      final w     = await ModelWeights.loadFromAsset(_weightsAsset);
      final p     = await DriftParams.loadFromAsset(_paramsAsset);
      final zones = HrZones(
        hrMax: widget.hrMax.toDouble(),
        zoneUpperFrac: widget.zoneUpperFrac,
      );

      final allFiles = await RideStorage.listRideFiles();
      // Exclude the current ride, take the 3 most recent others
      final others = allFiles
          .where((f) => f.path != widget.filePath)
          .take(3)
          .toList();

      final entries = <_CompareEntry>[];
      for (final f in others) {
        try {
          final rows    = await RideLoader.loadCsvFile(f.path);
          final result  = RideAnalyzer.analyze(rows: rows, weights: w, params: p, zones: zones);
          final rStats  = _RideStats.fromRows(rows);
          entries.add(_CompareEntry(
            label: _parseLabel(f.path.split('/').last),
            metrics: result.metrics,
            stats: rStats,
          ));
        } catch (_) {
          // skip unreadable rides
        }
      }

      setState(() {
        _compareEntries  = entries;
        _compareLoading  = false;
        _compareExpanded = true;
      });
    } catch (e) {
      setState(() => _compareLoading = false);
    }
  }

  String _parseLabel(String filename) {
    try {
      final core = filename.replaceFirst('ride_', '').replaceAll('.csv', '');
      if (RegExp(r'^\d{8}_\d{6}$').hasMatch(core)) {
        final month = int.parse(core.substring(4, 6));
        final day   = int.parse(core.substring(6, 8));
        final hour  = int.parse(core.substring(9, 11));
        final min   = int.parse(core.substring(11, 13));
        const months = ['Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
        return '${months[month-1]} $day  ${hour.toString().padLeft(2,'0')}:${min.toString().padLeft(2,'0')}';
      }
      return filename;
    } catch (_) {
      return filename;
    }
  }

  String _fmtDur(double sec) {
    final s  = sec.round();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _shareCsv() async {
    final f = File(widget.filePath);
    if (!await f.exists()) return;
    await Share.shareXFiles([XFile(f.path)], text: 'Pulze ride export CSV');
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.filePath.split('/').last;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
        actions: [
          IconButton(
            onPressed: _shareCsv,
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share CSV',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
          ? Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $_err',
              style: const TextStyle(color: Colors.red)))
          : _body(name),
    );
  }

  Widget _body(String name) {
    final r  = _res!;
    final m  = r.metrics;
    final st = _stats!;

    final xMin  = r.series.map((p) => p.tSec / 60.0).toList(growable: false);
    final obs   = r.series.map((p) => p.hrObs).toList(growable: false);
    final eff   = r.series.map((p) => p.hrEff).toList(growable: false);
    final drift = r.series.map((p) => p.drift).toList(growable: false);

    // Current ride as a compare entry
    final currentEntry = _CompareEntry(
      label: 'This ride',
      metrics: m,
      stats: st,
      isCurrent: true,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF888888))),
          const SizedBox(height: 14),

          // Ride Overview
          _sectionHeader('Ride Overview'),
          _kv('Duration',           _fmtDur(m.durationSec)),
          _kv('Avg HR',             '${m.avgHr.toStringAsFixed(0)} bpm'),
          _kv('Max HR',             '${m.maxHr.toStringAsFixed(0)} bpm'),

          const Divider(height: 26),

          // Drift Correction
          _sectionHeader('Drift Correction'),
          _kv('Max drift detected',        '${m.maxDrift.toStringAsFixed(1)} bpm'),
          _kv('End-of-ride drift',         '${m.endDrift.toStringAsFixed(1)} bpm'),
          _kv('Minutes correction active', '${m.minutesCorrected.toStringAsFixed(1)} min'),

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

          DriftLineChart(xMin: xMin, driftBpm: drift, height: 220),

          const Divider(height: 26),

          // Time in Zone
          _sectionHeader('Time in Zone — Raw vs Effective'),
          TimeInZoneBarChart(
            rawMin: m.timeInZoneRawMin,
            effMin: m.timeInZoneEffMin,
          ),

          const Divider(height: 26),

          // Compare with Recent Rides
          _CompareSection(
            currentEntry: currentEntry,
            compareEntries: _compareEntries,
            loading: _compareLoading,
            expanded: _compareExpanded,
            fmtDur: _fmtDur,
            onExpand: () {
              if (_compareEntries.isEmpty && !_compareLoading) {
                _loadComparison();
              } else {
                setState(() => _compareExpanded = !_compareExpanded);
              }
            },
          ),

          const SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: _shareCsv,
            icon: const Icon(Icons.download),
            label: const Text('Export / Share CSV'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold)),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
            child: Text(k,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(v),
      ],
    ),
  );
}

//
// Speed / grade / elevation stats  from raw RideRows
//
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
      final r      = rows[i];
      final double spd   = r.speedKmh as double;
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
      avgSpeedKmh:   speedSum / count,
      maxSpeedKmh:   speedMax,
      avgGradePct:   gradeSum / count,
      maxGradePct:   gradeMax == -999 ? 0 : gradeMax,
      minGradePct:   gradeMin == 999  ? 0 : gradeMin,
      elevationGainM: elevGain,
    );
  }
}

//
// Ride Stats card
//
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
              color: cs.primary),
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

//
// Compare entry model
//
class _CompareEntry {
  final String label;
  final RideMetrics metrics;
  final _RideStats stats;
  final bool isCurrent;

  const _CompareEntry({
    required this.label,
    required this.metrics,
    required this.stats,
    this.isCurrent = false,
  });
}

//
// Compare section widget
//
class _CompareSection extends StatelessWidget {
  final _CompareEntry currentEntry;
  final List<_CompareEntry> compareEntries;
  final bool loading;
  final bool expanded;
  final String Function(double) fmtDur;
  final VoidCallback onExpand;

  const _CompareSection({
    required this.currentEntry,
    required this.compareEntries,
    required this.loading,
    required this.expanded,
    required this.fmtDur,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header tap to expand
        GestureDetector(
          onTap: onExpand,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Row(
              children: [
                const Icon(Icons.compare_arrows_rounded,
                    color: Color(0xFFFF8C55), size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'COMPARE WITH RECENT RIDES',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                  ),
                ),
                if (loading)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF8C55)))
                else
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF888888),
                  ),
              ],
            ),
          ),
        ),

        // Expanded comparison table
        if (expanded) ...[
          const SizedBox(height: 12),
          if (compareEntries.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: const Center(
                child: Text(
                  'No other rides to compare yet.\nComplete more rides to see trends here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF666666), fontSize: 13),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Column(
                children: [
                  // Column headers
                  _tableHeader(context),
                  const Divider(height: 1, color: Color(0xFF2A2A2A)),
                  // Current ride row
                  _tableRow(context, currentEntry, isFirst: true),
                  // Other ride rows
                  ...compareEntries.asMap().entries.map((e) {
                    return Column(
                      children: [
                        const Divider(height: 1, color: Color(0xFF222222)),
                        _tableRow(context, e.value),
                      ],
                    );
                  }),
                  // Footer note
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: Text(
                      'Showing this ride vs up to 3 most recent rides.',
                      style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _tableHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          _hcell('Ride', flex: 3),
          _hcell('Dur'),
          _hcell('Avg HR'),
          _hcell('Drift'),
          _hcell('Spd'),
        ],
      ),
    );
  }

  Widget _hcell(String t, {int flex = 2}) => Expanded(
    flex: flex,
    child: Text(
      t,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF666666),
          letterSpacing: 0.4),
    ),
  );

  Widget _tableRow(BuildContext context, _CompareEntry e,
      {bool isFirst = false}) {
    final highlight = e.isCurrent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFFF8C55).withOpacity(0.07)
            : Colors.transparent,
        borderRadius: isFirst
            ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12))
            : null,
      ),
      child: Row(
        children: [
          // Ride label
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (highlight)
                  Container(
                    width: 3,
                    height: 28,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8C55),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Expanded(
                  child: Text(
                    e.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: highlight
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: highlight
                            ? const Color(0xFFFF8C55)
                            : Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Duration
          Expanded(
            flex: 2,
            child: _cell(fmtDur(e.metrics.durationSec), highlight),
          ),
          // Avg HR
          Expanded(
            flex: 2,
            child: _cell(
                '${e.metrics.avgHr.toStringAsFixed(0)} bpm', highlight),
          ),
          // Max drift
          Expanded(
            flex: 2,
            child: _cell(
                '${e.metrics.maxDrift.toStringAsFixed(1)} bpm', highlight),
          ),
          // Avg speed
          Expanded(
            flex: 2,
            child: _cell(
                '${e.stats.avgSpeedKmh.toStringAsFixed(1)} k', highlight),
          ),
        ],
      ),
    );
  }

  Widget _cell(String t, bool highlight) => Text(
    t,
    style: TextStyle(
        fontSize: 11,
        fontWeight:
        highlight ? FontWeight.w700 : FontWeight.w400,
        color: highlight ? Colors.white : const Color(0xFFAAAAAA)),
  );
}