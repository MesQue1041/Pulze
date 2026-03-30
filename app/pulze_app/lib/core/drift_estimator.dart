import 'dart:math';
import 'package:pulze_app/core/model_weights.dart';
import 'package:pulze_app/core/drift_params.dart';

class DriftState {
  double drift = 0.0;

  bool hasSessionOffset = false;
  double sessionOffset = 0.0;

  bool hasBaseline = false;
  double baselineResidual = 0.0;

  int posRun = 0;

  bool corrActive = false;
  int onRun = 0;
  int offRun = 0;
  int gapRun = 0;

  final List<double> pWindow = [];
  double? lastP;

  final List<double> calibResiduals = [];
  final List<double> baselineResiduals = [];
}

class DriftEstimator {
  final ModelWeights weights;
  final DriftParams p;

  DriftEstimator({required this.weights, required this.p});

  double predictExpected({
    required double pUsedRoll60,
    required double pUsed,
    required double speedKmh,
    required double gradeRoll2m,
  }) {
    final x = <double>[pUsedRoll60, pUsed, speedKmh, gradeRoll2m];

    double y = weights.intercept;
    for (int i = 0; i < x.length; i++) {
      final mu = weights.scalerMean[i];
      final sd = weights.scalerScale[i];
      final xs = (x[i] - mu) / (sd == 0.0 ? 1e-12 : sd);
      y += xs * weights.coef[i];
    }
    return y;
  }

  double _median(List<double> a) {
    if (a.isEmpty) return 0.0;
    final b = List<double>.from(a)..sort();
    final mid = b.length ~/ 2;
    if (b.length.isOdd) return b[mid];
    return 0.5 * (b[mid - 1] + b[mid]);
  }

  bool _updateCorrActive(DriftState s, bool steadyRaw) {
    if (steadyRaw) {
      s.onRun++;
      s.offRun = 0;
    } else {
      s.offRun++;
      s.onRun = 0;
    }

    if (!s.corrActive) {
      if (s.onRun >= max(1, p.debounceOnSamples)) {
        s.corrActive = true;
        s.gapRun = 0;
      }
    } else {
      if (steadyRaw) {
        s.gapRun = 0;
      } else {
        s.gapRun += 1;
        if (s.gapRun > max(1, p.holdGapSamples) &&
            s.offRun >= max(1, p.debounceOffSamples)) {
          s.corrActive = false;
          s.gapRun = 0;
        }
      }
    }

    return s.corrActive;
  }

  double _std(List<double> a) {
    if (a.length < 2) return double.infinity;
    final m = a.reduce((x, y) => x + y) / a.length;
    double s2 = 0.0;
    for (final v in a) {
      final d = v - m;
      s2 += d * d;
    }
    s2 /= (a.length - 1);
    return sqrt(s2);
  }

  void _pushP(DriftState s, double pUsed) {
    s.pWindow.add(pUsed);
    if (s.pWindow.length > p.pStdWindowSamples) {
      s.pWindow.removeAt(0);
    }
  }

  bool _steadyGated({
    required DriftState s,
    required bool steadyRaw,
    required double pUsed,
    required double pUsedRoll60,
    required double speedKmh,
  }) {
    if (!steadyRaw) return false;
    if (pUsedRoll60 < p.pMinActive) return false;
    if (speedKmh < p.speedMinActive) return false;

    _pushP(s, pUsed);

    final pStd = _std(s.pWindow);
    if (pStd.isFinite && pStd > p.pStdMax60s) return false;

    final last = s.lastP;
    s.lastP = pUsed;
    if (last != null && (pUsed - last).abs() > p.pJumpMax5s) return false;

    return true;
  }

  double _clampDelta(double from, double to, double maxDelta) {
    final d = to - from;
    if (d > maxDelta) return from + maxDelta;
    if (d < -maxDelta) return from - maxDelta;
    return to;
  }

  Map<String, dynamic> update({
    required DriftState state,
    required double elapsedSeconds,
    required double hr,
    required double pUsed,
    required double pUsedRoll60,
    required double speedKmh,
    required double gradeRoll2m,
    required bool steadyRaw,
    bool demoMode = false,
    bool? demoCorrMask,
  }) {
    final expected = predictExpected(
      pUsedRoll60: pUsedRoll60,
      pUsed: pUsed,
      speedKmh: speedKmh,
      gradeRoll2m: gradeRoll2m,
    );

    final steadyOk = _steadyGated(
      s: state,
      steadyRaw: steadyRaw,
      pUsed: pUsed,
      pUsedRoll60: pUsedRoll60,
      speedKmh: speedKmh,
    );

    final corrDebounced = _updateCorrActive(state, steadyOk);
    final bool corr = demoMode ? (demoCorrMask ?? corrDebounced) : corrDebounced;

    if (!state.hasSessionOffset && corr && elapsedSeconds <= p.calibSec) {
      state.calibResiduals.add(hr - expected);
    }
    if (!state.hasSessionOffset &&
        (state.calibResiduals.length >= p.minCalibSamples ||
            elapsedSeconds > p.calibSec)) {
      state.sessionOffset = _median(state.calibResiduals)
          .clamp(-p.sessionOffsetClampBpm, p.sessionOffsetClampBpm);
      state.hasSessionOffset = true;
    }

    final expectedAdj =
        expected + (state.hasSessionOffset ? state.sessionOffset : 0.0);

    final resid = hr - expectedAdj;

    if (!state.hasBaseline && corr && elapsedSeconds <= p.baselineSec) {
      state.baselineResiduals.add(resid);
    }
    if (!state.hasBaseline &&
        (state.baselineResiduals.length >= 20 ||
            elapsedSeconds > p.baselineSec)) {
      state.baselineResidual = _median(state.baselineResiduals);
      state.hasBaseline = true;
    }

    final residAdj = resid - (state.hasBaseline ? state.baselineResidual : 0.0);

    final bool allowDriftNow = elapsedSeconds >= p.driftStartSec;

    if (allowDriftNow && corr && residAdj >= p.posResidThresh) {
      state.posRun++;
    } else {
      state.posRun = 0;
      state.drift *= p.driftDecay;
      if (state.drift < 0.001) state.drift = 0.0;
    }

    if (allowDriftNow && state.posRun >= p.posPersistSamples) {
      double proposed =
          p.ewmaAlpha * residAdj + (1.0 - p.ewmaAlpha) * state.drift;

      proposed = proposed.clamp(0.0, p.driftClipBpm);

      state.drift =
          _clampDelta(state.drift, proposed, p.driftMaxDeltaPerSample);
    }

    final hrEffective = (corr && allowDriftNow) ? hr - state.drift : hr;

    return {
      "expectedAdj": expectedAdj,
      "drift": state.drift,
      "hrEffective": hrEffective,
      "corrActive": corr,
      "steadyOk": steadyOk,
      "driftAllowed": allowDriftNow,
      "sessionOffset": state.sessionOffset,
      "baselineResidual": state.baselineResidual,
    };
  }
}