import 'dart:io';

class RideRecorder {
  IOSink? _sink;
  File? _file;
  bool _started = false;

  File? get file => _file;
  bool get isRecording => _started;

  /// Creates CSV and writes header.
  Future<void> start(File file) async {
    _file = file;

    // Ensure parent exists
    await file.parent.create(recursive: true);

    _sink = file.openWrite(mode: FileMode.writeOnly);

    // Header must match RideLoader requirements
    _sink!.writeln([
      "elapsed_seconds",
      "hr",
      "P_used",
      "P_used_roll_60s",
      "speed_kmh_clean",
      "grade_roll_2m",
      "corr_active",
    ].join(","));

    _started = true;
  }

  /// Append one row (no buffering issues, IO is cheap enough at ~4Hz).
  void writeRow({
    required double elapsedSec,
    required int hr,
    required double pUsed,
    required double pUsedRoll60,
    required double speedKmhClean,
    required double gradeRoll2m,
    required int corrActive,
  }) {
    if (!_started || _sink == null) return;

    // Avoid commas in floats, use dot decimal.
    final row = [
      elapsedSec.toStringAsFixed(2),
      hr.toString(),
      pUsed.toStringAsFixed(3),
      pUsedRoll60.toStringAsFixed(3),
      speedKmhClean.toStringAsFixed(3),
      gradeRoll2m.toStringAsFixed(6),
      corrActive.toString(),
    ].join(",");

    _sink!.writeln(row);
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;

    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}
