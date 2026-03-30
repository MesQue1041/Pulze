import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

class DriftParams {
  final int resampleSeconds;

  final double ewmaAlpha;
  final double driftClipBpm;

  final double posResidThresh;
  final int posPersistSec;

  final double pStdMax60s;
  final double pJumpMax5s;
  final double pMinActive;
  final double speedMinActive;

  final double driftDecay;
  final int baselineMin;
  final int minSteadyPowerSec;

  final int? minSteadyForDriftSec;
  final int calibMinSession;

  // App only stability knobs
  final int debounceOnSec;
  final int debounceOffSec;
  final int holdGapSec;

  // calibration requirements
  final int minCalibSamples;

  // Safety clamps
  final double sessionOffsetClampBpm;


  final int driftStartMin;

  // Drift slew-rate limiter
  final double driftMaxChangeBpmPerMin;

  DriftParams({
    required this.resampleSeconds,
    required this.ewmaAlpha,
    required this.driftClipBpm,
    required this.posResidThresh,
    required this.posPersistSec,
    required this.pStdMax60s,
    required this.pJumpMax5s,
    required this.pMinActive,
    required this.speedMinActive,
    required this.driftDecay,
    required this.baselineMin,
    required this.minSteadyPowerSec,
    required this.minSteadyForDriftSec,
    required this.calibMinSession,
    this.debounceOnSec = 30,
    this.debounceOffSec = 20,
    this.holdGapSec = 25,
    this.minCalibSamples = 40,
    this.sessionOffsetClampBpm = 15.0,
    this.driftStartMin = 20,
    this.driftMaxChangeBpmPerMin = 3.0,
  });

  //  helpers
  int get posPersistSamples => max1((posPersistSec / resampleSeconds).round());
  int get calibSec => calibMinSession * 60;
  int get baselineSec => baselineMin * 60;

  int get debounceOnSamples => max1((debounceOnSec / resampleSeconds).round());
  int get debounceOffSamples => max1((debounceOffSec / resampleSeconds).round());
  int get holdGapSamples => max1((holdGapSec / resampleSeconds).round());

  int get pStdWindowSamples => max1((60 / resampleSeconds).round());

  int get driftStartSec => driftStartMin * 60;

  // Max drift delta per estimator
  double get driftMaxDeltaPerSample =>
      driftMaxChangeBpmPerMin * (resampleSeconds / 60.0);

  static int max1(int x) => x < 1 ? 1 : x;

  static Future<DriftParams> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final j = jsonDecode(raw) as Map<String, dynamic>;

    int rs = (j["RESAMPLE_SECONDS"] as num).toInt();

    double ewma = (j["EWMA_ALPHA"] as num).toDouble();
    double clip = (j["DRIFT_CLIP_BPM"] as num).toDouble();

    double posThresh = (j["POS_RESID_THRESH"] as num).toDouble();
    int posSec = (j["POS_PERSIST_SEC"] as num).toInt();

    double pStd = (j["P_STD_MAX_60S"] as num).toDouble();
    double pJump = (j["P_JUMP_MAX_5S"] as num).toDouble();
    double pMin = (j["P_MIN_ACTIVE"] as num).toDouble();
    double sMin = (j["SPEED_MIN_ACTIVE"] as num).toDouble();

    double decay = (j["DRIFT_DECAY"] as num).toDouble();
    int baselineMin = (j["BASELINE_MIN"] as num).toInt();
    int minSteadyPowerSec = (j["MIN_STEADY_POWER_SEC"] as num).toInt();

    int? minSteadyForDriftSec;
    if (j.containsKey("MIN_STEADY_FOR_DRIFT_SEC") &&
        j["MIN_STEADY_FOR_DRIFT_SEC"] != null) {
      minSteadyForDriftSec = (j["MIN_STEADY_FOR_DRIFT_SEC"] as num).toInt();
    }

    int calibMin = 12;
    if (j.containsKey("CALIB_MIN_SESSION") && j["CALIB_MIN_SESSION"] != null) {
      calibMin = (j["CALIB_MIN_SESSION"] as num).toInt();
    }

    int driftStartMin = 20;
    if (j.containsKey("DRIFT_START_MIN") && j["DRIFT_START_MIN"] != null) {
      driftStartMin = (j["DRIFT_START_MIN"] as num).toInt();
    }

    // Optional override
    double maxChange = 3.0;
    if (j.containsKey("DRIFT_MAX_CHANGE_BPM_PER_MIN") &&
        j["DRIFT_MAX_CHANGE_BPM_PER_MIN"] != null) {
      maxChange = (j["DRIFT_MAX_CHANGE_BPM_PER_MIN"] as num).toDouble();
    }

    return DriftParams(
      resampleSeconds: rs,
      ewmaAlpha: ewma,
      driftClipBpm: clip,
      posResidThresh: posThresh,
      posPersistSec: posSec,
      pStdMax60s: pStd,
      pJumpMax5s: pJump,
      pMinActive: pMin,
      speedMinActive: sMin,
      driftDecay: decay,
      baselineMin: baselineMin,
      minSteadyPowerSec: minSteadyPowerSec,
      minSteadyForDriftSec: minSteadyForDriftSec,
      calibMinSession: calibMin,
      driftStartMin: driftStartMin,
      driftMaxChangeBpmPerMin: maxChange,
    );
  }
}
