class AppSettings {

  final String hrMaxMode;
  final int age;
  final int customHrMax;

  //  [0.60, 0.70, 0.80, 0.90]
  final List<double> zoneUpperFrac;

  // Drift start minute
  final int driftStartMin;

  // Weight for proxy physics
  final double weightKg;

  const AppSettings({
    required this.hrMaxMode,
    required this.age,
    required this.customHrMax,
    required this.zoneUpperFrac,
    required this.driftStartMin,
    required this.weightKg,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      hrMaxMode: "age",
      age: 25,
      customHrMax: 190,
      zoneUpperFrac: [0.60, 0.70, 0.80, 0.90],
      driftStartMin: 10,
      weightKg: 75.0,
    );
  }

  int get hrMaxResolved {
    if (hrMaxMode == "custom") return customHrMax;
    return 220 - age;
  }

  AppSettings copyWith({
    String? hrMaxMode,
    int? age,
    int? customHrMax,
    List<double>? zoneUpperFrac,
    int? driftStartMin,
    double? weightKg,
  }) {
    return AppSettings(
      hrMaxMode: hrMaxMode ?? this.hrMaxMode,
      age: age ?? this.age,
      customHrMax: customHrMax ?? this.customHrMax,
      zoneUpperFrac: zoneUpperFrac ?? List<double>.from(this.zoneUpperFrac),
      driftStartMin: driftStartMin ?? this.driftStartMin,
      weightKg: weightKg ?? this.weightKg,
    );
  }
}