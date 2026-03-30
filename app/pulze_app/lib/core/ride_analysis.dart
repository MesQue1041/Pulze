import 'dart:math';

import 'model_weights.dart';
import 'drift_estimator.dart';
import 'drift_params.dart';
import 'ride_row.dart';
import 'zones.dart';

class RidePoint {
  final double tSec;
  final double hrObs;
  final double hrEff;
  final double hrExp;
  final double drift;
  final bool corrActive;

  RidePoint({
    required this.tSec,
    required this.hrObs,
    required this.hrEff,
    required this.hrExp,
    required this.drift,
    required this.corrActive,
  });
}

class RideMetrics {
  final double durationSec;
  final double avgHr;
  final double maxHr;

  final double maxDrift;
  final double endDrift;
  final double minutesCorrected;

  final List<double> timeInZoneRawMin;
  final List<double> timeInZoneEffMin;

  final double avgPUsedRoll60;
  final double elevationGainM;

  RideMetrics({
    required this.durationSec,
    required this.avgHr,
    required this.maxHr,
    required this.maxDrift,
    required this.endDrift,
    required this.minutesCorrected,
    required this.timeInZoneRawMin,
    required this.timeInZoneEffMin,
    required this.avgPUsedRoll60,
    required this.elevationGainM,
  });
}

class RideAnalysisResult {
  final List<RidePoint> series;
  final RideMetrics metrics;

  RideAnalysisResult({required this.series, required this.metrics});
}

class RideAnalyzer {
  static RideAnalysisResult analyze({
    required List<RideRow> rows,
    required ModelWeights weights,
    required DriftParams params,
    required HrZones zones,
  }) {
    if (rows.isEmpty) {
      throw StateError("No ride rows to analyze.");
    }

    final est = DriftEstimator(weights: weights, p: params);
    final st = DriftState();


    double t0 = rows.first.tSec;
    double tEnd = rows.last.tSec;

    double hrSum = 0.0;
    double hrMax = -1e9;

    double maxDrift = 0.0;
    double endDrift = 0.0;

    double correctedSec = 0.0;

    final rawZoneSec = List<double>.filled(5, 0.0);
    final effZoneSec = List<double>.filled(5, 0.0);

    double p60Sum = 0.0;
    int p60Count = 0;

    double elevationGainM = 0.0;

    final out = <RidePoint>[];

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];

      final double t = r.tSec;
      final double hr = r.hr;
      final bool corrMask = r.corrActive == 1;

      final bool steadyRaw = r.speedKmh >= 2.0;

      final m = est.update(
        state: st,
        elapsedSeconds: t,
        hr: hr,
        pUsed: r.pUsed,
        pUsedRoll60: r.pUsed60,
        speedKmh: r.speedKmh,
        gradeRoll2m: r.grade2m,
        steadyRaw: steadyRaw,
        demoMode: true,
        demoCorrMask: corrMask,
      );

      final double expectedAdj = (m["expectedAdj"] as num).toDouble();
      final double drift = (m["drift"] as num).toDouble();
      final double hrEff = (m["hrEffective"] as num).toDouble();
      final bool corrActive = (m["corrActive"] as bool);

      out.add(RidePoint(
        tSec: t,
        hrObs: hr,
        hrEff: hrEff,
        hrExp: expectedAdj,
        drift: drift,
        corrActive: corrActive,
      ));

      hrSum += hr;
      hrMax = max(hrMax, hr);
      maxDrift = max(maxDrift, drift);
      endDrift = drift;

      if (r.pUsed60.isFinite) {
        p60Sum += r.pUsed60;
        p60Count++;
      }


      final double dt = (i == 0)
          ? params.resampleSeconds.toDouble()
          : max(0.0, rows[i].tSec - rows[i - 1].tSec);

      if (corrActive) correctedSec += dt;

      final int zRaw = zones.zoneOf(hr);
      final int zEff = zones.zoneOf(hrEff);

      rawZoneSec[zRaw - 1] += dt;
      effZoneSec[zEff - 1] += dt;
    }

    final durationSec = max(0.0, tEnd - t0);
    final avgHr = hrSum / rows.length;

    final timeInZoneRawMin = rawZoneSec.map((s) => s / 60.0).toList(growable: false);
    final timeInZoneEffMin = effZoneSec.map((s) => s / 60.0).toList(growable: false);

    final metrics = RideMetrics(
      durationSec: durationSec,
      avgHr: avgHr,
      maxHr: hrMax.isFinite ? hrMax : 0.0,
      maxDrift: maxDrift,
      endDrift: endDrift,
      minutesCorrected: correctedSec / 60.0,
      timeInZoneRawMin: timeInZoneRawMin,
      timeInZoneEffMin: timeInZoneEffMin,
      avgPUsedRoll60: p60Count > 0 ? (p60Sum / p60Count) : 0.0,
      elevationGainM: elevationGainM,
    );

    return RideAnalysisResult(series: out, metrics: metrics);
  }
}