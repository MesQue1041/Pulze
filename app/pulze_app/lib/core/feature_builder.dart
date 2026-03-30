import 'dart:math';
import 'gps_service.dart';

class LiveFeatures {
  final double tSec;
  final double speedKmhClean;
  final double gradeRoll2m;
  final double pUsed;
  final double pUsedRoll60;

  //  convenience flag
  final bool steadyRaw;

  LiveFeatures({
    required this.tSec,
    required this.speedKmhClean,
    required this.gradeRoll2m,
    required this.pUsed,
    required this.pUsedRoll60,
    required this.steadyRaw,
  });
}

class FeatureBuilder {
  /// User config like total mass (rider + bike)
  /// Used only for the climb term in the proxy workload
  double massKg;

  double get weightKg => massKg;
  set weightKg(double v) => massKg = v;

  FeatureBuilder({double massKg = 70.0, double? weightKg})
      : massKg = (weightKg ?? massKg);

  // last GPS for delta-based speed and grade
  GpsSample? _prev;

  // time buffers for smoothing
  final List<(double tSec, double grade)> _gradeBuf = [];
  final List<(double tSec, double p)> _pBuf = [];

  LiveFeatures updateFromGps(GpsSample s) {
    // we use GPS speed if provided or else we compute from haversine deltas
    double speedMps = s.speedMps;
    if (speedMps <= 0.1 && _prev != null) {
      final dt = max(0.2, s.tSec - _prev!.tSec);
      final dist = _haversineM(_prev!.lat, _prev!.lon, s.lat, s.lon);
      speedMps = dist / dt;
    }
    final speedKmh = max(0.0, speedMps * 3.6);

    // Grade is dAlt and horizDist
    double grade = 0.0;
    if (_prev != null) {
      final dist = _haversineM(_prev!.lat, _prev!.lon, s.lat, s.lon);
      final dAlt = s.altitudeM - _prev!.altitudeM;
      if (dist >= 3.0) {
        grade = (dAlt / dist);
        grade = grade.clamp(-0.25, 0.25);
      }
    }

    // Smooth grade over 2 minutes
    _gradeBuf.add((s.tSec, grade));
    _trimBuf(_gradeBuf, windowSec: 120.0, now: s.tSec);
    final gradeRoll2m = _mean(_gradeBuf.map((e) => e.$2).toList());

    // Workload proxy
    final v = speedMps;
    const g = 9.81;

    final aero = 0.30 * pow(v, 3);
    final roll = 6.0 * v;
    final climb = massKg * g * max(0.0, gradeRoll2m) * v * 0.35;

    final pUsed = max(0.0, aero + roll + climb);

    // Smooth P over 60s
    _pBuf.add((s.tSec, pUsed));
    _trimBuf(_pBuf, windowSec: 60.0, now: s.tSec);
    final pUsedRoll60 = _mean(_pBuf.map((e) => e.$2).toList());

    _prev = s;

    // speed clean clamp
    final speedKmhClean = speedKmh.clamp(0.0, 80.0);

    // simple steady flag for gating

    final steadyRaw = speedKmhClean >= 2.0;

    return LiveFeatures(
      tSec: s.tSec,
      speedKmhClean: speedKmhClean,
      gradeRoll2m: gradeRoll2m,
      pUsed: pUsed,
      pUsedRoll60: pUsedRoll60,
      steadyRaw: steadyRaw,
    );
  }

  void reset() {
    _prev = null;
    _gradeBuf.clear();
    _pBuf.clear();
  }

  void _trimBuf(List<(double, double)> buf,
      {required double windowSec, required double now}) {
    final minT = now - windowSec;
    while (buf.isNotEmpty && buf.first.$1 < minT) {
      buf.removeAt(0);
    }
  }

  double _mean(List<double> a) {
    if (a.isEmpty) return 0.0;
    double s = 0.0;
    for (final v in a) s += v;
    return s / a.length;
  }

  double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double d) => d * pi / 180.0;
}