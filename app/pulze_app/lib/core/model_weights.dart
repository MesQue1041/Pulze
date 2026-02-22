import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Holds the linear model weights exported from Colab:
/// expected_hr_global.json
///
/// Expected JSON fields:
/// - feat_cols
/// - scaler_mean
/// - scaler_scale
/// - intercept
/// - coef
/// - model_type
class ModelWeights {
  final List<String> featCols;
  final List<double> scalerMean;
  final List<double> scalerScale;
  final double intercept;
  final List<double> coef;
  final String modelType;

  ModelWeights({
    required this.featCols,
    required this.scalerMean,
    required this.scalerScale,
    required this.intercept,
    required this.coef,
    required this.modelType,
  });

  static Future<ModelWeights> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final j = jsonDecode(raw) as Map<String, dynamic>;

    List<String> featCols = (j["feat_cols"] as List).map((e) => e.toString()).toList();
    List<double> mean = (j["scaler_mean"] as List).map((e) => (e as num).toDouble()).toList();
    List<double> scale = (j["scaler_scale"] as List).map((e) => (e as num).toDouble()).toList();
    double intercept = (j["intercept"] as num).toDouble();
    List<double> coef = (j["coef"] as List).map((e) => (e as num).toDouble()).toList();
    String modelType = (j["model_type"] ?? "linear").toString();

    // basic sanity checks
    if (featCols.length != mean.length || featCols.length != scale.length || featCols.length != coef.length) {
      throw StateError("ModelWeights: feat_cols, scaler_mean, scaler_scale, coef must have same length.");
    }

    return ModelWeights(
      featCols: featCols,
      scalerMean: mean,
      scalerScale: scale,
      intercept: intercept,
      coef: coef,
      modelType: modelType,
    );
  }
}
