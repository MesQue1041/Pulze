import 'package:pulze_app/core/model_weights.dart';

class ExpectedHrPredictor {
  final ModelWeights w;

  ExpectedHrPredictor(this.w);

  double predict(Map<String, double> feats) {

    final x = <double>[
      feats["P_used_roll_60s"] ?? 0.0,
      feats["P_used"] ?? 0.0,
      feats["speed_kmh_clean"] ?? 0.0,
      feats["grade_roll_2m"] ?? 0.0,
    ];

    double y = w.intercept;
    for (int i = 0; i < x.length; i++) {
      final mu = w.scalerMean[i];
      final sd = w.scalerScale[i];
      final xs = (x[i] - mu) / ((sd == 0.0) ? 1e-12 : sd);
      y += xs * w.coef[i];
    }
    return y;
  }
}
