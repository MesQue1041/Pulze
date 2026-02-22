import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DriftLineChart extends StatelessWidget {
  final List<double> xMin;
  final List<double> driftBpm;
  final double height;

  const DriftLineChart({
    super.key,
    required this.xMin,
    required this.driftBpm,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final n = min(xMin.length, driftBpm.length);
    if (n == 0) return const SizedBox(height: 200, child: Center(child: Text("No data")));

    double minY = 1e9, maxY = -1e9;
    for (int i = 0; i < n; i++) {
      final v = driftBpm[i];
      if (!v.isFinite) continue;
      minY = min(minY, v);
      maxY = max(maxY, v);
    }
    if (!minY.isFinite || !maxY.isFinite) {
      minY = 0;
      maxY = 10;
    }

    // Drift is usually 0..~15 so we keep it tight.
    final pad = max(1.0, (maxY - minY) * 0.15);
    minY -= pad;
    maxY += pad;

    final spots = <FlSpot>[];
    for (int i = 0; i < n; i++) {
      final xv = xMin[i];
      final yv = driftBpm[i];
      if (xv.isFinite && yv.isFinite) spots.add(FlSpot(xv, yv));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Drift (bpm)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: _niceInterval(xMin.last),
                    getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0)),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: _niceInterval(maxY - minY),
                    getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0)),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static double _niceInterval(double span) {
    if (!span.isFinite || span <= 0) return 1;
    if (span <= 5) return 1;
    if (span <= 10) return 2;
    if (span <= 20) return 5;
    if (span <= 50) return 10;
    return 20;
  }
}