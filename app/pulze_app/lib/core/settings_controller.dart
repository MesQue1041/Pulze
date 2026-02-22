class PulzeSettings {
  // Profile
  int age;
  double weightKg;

  // HRmax
  bool useDefaultHrMax; // 220-age
  double customHrMax;

  // Drift
  int driftStartMin;

  // Zones (fractions of HRmax)
  bool useCustomZones;
  List<double> zoneUpperFrac; // len 5, last should be 1.0

  PulzeSettings({
    this.age = 24,
    this.weightKg = 70.0,
    this.useDefaultHrMax = true,
    this.customHrMax = 190.0,
    this.driftStartMin = 20,
    this.useCustomZones = false,
    List<double>? zoneUpperFrac,
  }) : zoneUpperFrac = zoneUpperFrac ?? const [0.60, 0.70, 0.80, 0.90, 1.00];

  int get hrMaxResolved => useDefaultHrMax ? (220 - age) : customHrMax.round();

  List<double> get zoneUpperFracResolved {
    if (!useCustomZones) {
      return const [0.60, 0.70, 0.80, 0.90, 1.00];
    }
    return zoneUpperFrac;
  }
}

class SettingsController {
  PulzeSettings settings = PulzeSettings();

  // Profile
  void setAge(int v) => settings.age = v;
  void setWeightKg(double v) => settings.weightKg = v;

  // HRmax
  void setUseDefaultHrMax(bool v) => settings.useDefaultHrMax = v;
  void setCustomHrMax(double v) {
    settings.customHrMax = v;
    settings.useDefaultHrMax = false;
  }

  // Drift
  void setDriftStartMin(int v) => settings.driftStartMin = v;

  // Zones
  void setUseCustomZones(bool v) => settings.useCustomZones = v;
  void setZoneUpperFrac(List<double> v) => settings.zoneUpperFrac = v;
}