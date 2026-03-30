import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

const Color _kObserved  = Color(0xFF5BC8F5);
const Color _kEffective = Color(0xFFFF8C55);

class HrCompareChart extends StatelessWidget {
  final List<double> xMin;
  final List<double> hrObserved;
  final List<double> hrEffective;
  final double height;

  const HrCompareChart({
    super.key,
    required this.xMin,
    required this.hrObserved,
    required this.hrEffective,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    final n = min(xMin.length, min(hrObserved.length, hrEffective.length));
    if (n == 0) {
      return const SizedBox(
          height: 200, child: Center(child: Text('No data')));
    }

    double minY = 1e9, maxY = -1e9;
    void upd(double v) {
      if (!v.isFinite) return;
      minY = min(minY, v);
      maxY = max(maxY, v);
    }

    for (int i = 0; i < n; i++) {
      upd(hrObserved[i]);
      upd(hrEffective[i]);
    }

    if (!minY.isFinite || !maxY.isFinite) {
      minY = 0;
      maxY = 200;
    }
    final pad = max(5.0, (maxY - minY) * 0.10);
    minY -= pad;
    maxY += pad;

    List<FlSpot> spots(List<double> y) {
      final out = <FlSpot>[];
      for (int i = 0; i < n; i++) {
        final xv = xMin[i];
        final yv = y[i];
        if (xv.isFinite && yv.isFinite) out.add(FlSpot(xv, yv));
      }
      return out;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Legend(),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: _niceInterval(xMin.last),
                    getTitlesWidget: (v, meta) =>
                        Text(v.toStringAsFixed(0)),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: _niceInterval(maxY - minY),
                    getTitlesWidget: (v, meta) =>
                        Text(v.toStringAsFixed(0)),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots(hrObserved),
                  isCurved: true,
                  color: _kObserved,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: spots(hrEffective),
                  isCurved: true,
                  color: _kEffective,
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) {
      return Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        children: [
          item(_kObserved,  'Observed HR'),
          item(_kEffective, 'Effective HR'),
        ],
      ),
    );
  }
}