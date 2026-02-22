import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TimeInZoneBarChart extends StatelessWidget {
  final List<double> rawMin;
  final List<double> effMin;
  final double height;

  const TimeInZoneBarChart({
    super.key,
    required this.rawMin,
    required this.effMin,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    // Force everything to double so dart:math max doesn't widen to num
    final double rawMax = rawMin.isEmpty ? 0.0 : rawMin.reduce((a, b) => max(a, b));
    final double effMax = effMin.isEmpty ? 0.0 : effMin.reduce((a, b) => max(a, b));
    final double maxY = max(rawMax, effMax);

    final double safeMaxY = (maxY.isFinite ? maxY : 1.0) + 1.0;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: safeMaxY,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: _niceInterval(maxY),
                getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i > 4) return const SizedBox.shrink();
                  return Text("Z${i + 1}");
                },
              ),
            ),
          ),
          barGroups: List.generate(5, (i) {
            final double r = (i < rawMin.length) ? rawMin[i] : 0.0;
            final double e = (i < effMin.length) ? effMin[i] : 0.0;

            return BarChartGroupData(
              x: i,
              barsSpace: 6,
              barRods: [
                BarChartRodData(toY: r.isFinite ? r : 0.0, width: 10),
                BarChartRodData(toY: e.isFinite ? e : 0.0, width: 10),
              ],
            );
          }),
        ),
      ),
    );
  }

  static double _niceInterval(double maxY) {
    if (!maxY.isFinite || maxY <= 0) return 1.0;
    if (maxY <= 5) return 1.0;
    if (maxY <= 10) return 2.0;
    if (maxY <= 20) return 5.0;
    return 10.0;
  }
}