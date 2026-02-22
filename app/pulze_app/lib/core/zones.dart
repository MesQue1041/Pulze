class HrZones {
  final double hrMax;

  /// Upper bounds for zones 1..4 expressed as fraction of HRmax.
  /// Zone 5 is implicitly 1.0.
  /// Example: [0.60, 0.70, 0.80, 0.90]
  final List<double> zoneUpperFrac;

  HrZones({
    required this.hrMax,
    List<double>? zoneUpperFrac,
  }) : zoneUpperFrac = (zoneUpperFrac != null && zoneUpperFrac.length == 4)
      ? List<double>.from(zoneUpperFrac)
      : const [0.60, 0.70, 0.80, 0.90];

  int zoneOf(double hr) {
    final z1 = zoneUpperFrac[0] * hrMax;
    final z2 = zoneUpperFrac[1] * hrMax;
    final z3 = zoneUpperFrac[2] * hrMax;
    final z4 = zoneUpperFrac[3] * hrMax;

    if (hr < z1) return 1;
    if (hr < z2) return 2;
    if (hr < z3) return 3;
    if (hr < z4) return 4;
    return 5;
  }
}