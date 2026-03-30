import 'dart:io';

class RideRecorder {
  IOSink? _sink;
  File? _file;
  bool _started = false;

  File? get file => _file;
  bool get isRecording => _started;

  Future<void> start(File file) async {
    _file = file;
    await file.parent.create(recursive: true);
    _sink = file.openWrite(mode: FileMode.writeOnly);


    _sink!.writeln([
      'elapsedseconds',
      'hr',
      'Pused',
      'Pusedroll60s',
      'speedkmhclean',
      'graderoll2m',
      'corractive',

      'expectedhr',
      'effectivehr',
      'drift',
      'rawzone',
      'effectivezone',
      'steadyok',
      'driftallowed',
    ].join(','));

    _started = true;
  }

  void writeRow({
    required double elapsedSec,
    required int hr,
    required double pUsed,
    required double pUsedRoll60,
    required double speedKmhClean,
    required double gradeRoll2m,
    required int corrActive,

    required double expectedHr,
    required double effectiveHr,
    required double drift,
    required int rawZone,
    required int effectiveZone,
    required bool steadyOk,
    required bool driftAllowed,
  }) {
    if (!_started || _sink == null) return;

    final row = [
      elapsedSec.toStringAsFixed(2),
      hr.toString(),
      pUsed.toStringAsFixed(3),
      pUsedRoll60.toStringAsFixed(3),
      speedKmhClean.toStringAsFixed(3),
      gradeRoll2m.toStringAsFixed(6),
      corrActive.toString(),
      expectedHr.toStringAsFixed(2),
      effectiveHr.toStringAsFixed(2),
      drift.toStringAsFixed(3),
      rawZone.toString(),
      effectiveZone.toString(),
      steadyOk ? '1' : '0',
      driftAllowed ? '1' : '0',
    ].join(',');

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