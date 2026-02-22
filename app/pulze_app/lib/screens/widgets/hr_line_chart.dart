import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HrLineChart extends StatelessWidget {
  final List<double> xMin;
  final List<double> hrObs;
  final List<double> hrEff;
  final List<double> hrExp;
  final List<double> drift;

  final bool showLegend;
  final double height;

  const HrLineChart({
    super.key,
    required this.xMin,
    required this.hrObs,
    required this.hrEff,
    required this.hrExp,
    required this.drift,
    this.showLegend = true,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    final n = xMin.length;
    if (n == 0) {
      return const SizedBox(height: 200, child: Center(child: Text("No data")));
    }

    double minY = 1e9, maxY = -1e9;
    void upd(List<double> a) {
      for (final v in a) {
        if (!v.isFinite) continue;
        minY = min(minY, v);
        maxY = max(maxY, v);
      }
    }

    upd(hrObs);
    upd(hrEff);
    upd(hrExp);

    upd(drift.map((d) => d).toList());

    if (!minY.isFinite || !maxY.isFinite) {
      minY = 0;
      maxY = 200;
    }

    final pad = max(5.0, (maxY - minY) * 0.08);
    minY -= pad;
    maxY += pad;

    List<FlSpot> spots(List<double> y) {
      final out = <FlSpot>[];
      for (int i = 0; i < n; i++) {
        final xv = xMin[i];
        final yv = y[i];
        if (xv.isFinite && yv.isFinite) {
          out.add(FlSpot(xv, yv));
        }
      }
      return out;
    }

    final obsSpots = spots(hrObs);
    final effSpots = spots(hrEff);
    final expSpots = spots(hrExp);
    final driftSpots = spots(drift);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLegend) const _Legend(),
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
                  spots: obsSpots,
                  isCurved: true,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: effSpots,
                  isCurved: true,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: expSpots,
                  isCurved: true,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: driftSpots,
                  isCurved: true,
                  barWidth: 2,
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(String t) => Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        children: [
          item("Observed HR"),
          item("Effective HR"),
          item("Expected HR"),
          item("Drift"),
        ],
      ),
    );
  }
}