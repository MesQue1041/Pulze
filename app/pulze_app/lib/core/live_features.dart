import 'dart:async';

import 'feature_builder.dart';
import 'gps_service.dart';


class LiveFeaturesEngine {
  final GpsService gps;
  final FeatureBuilder builder;
  final int resampleSeconds;

  StreamSubscription<GpsSample>? _gpsSub;
  Timer? _timer;

  GpsSample? _last;
  bool _hasFix = false;

  late DateTime _startWall;
  double _elapsedSec = 0.0;

  final _out = StreamController<LiveFeatures>.broadcast();
  Stream<LiveFeatures> get stream => _out.stream;

  LiveFeaturesEngine({
    required this.gps,
    required this.builder,
    required this.resampleSeconds,
  });

  bool get isRunning => _timer != null;

  Future<void> start() async {
    if (isRunning) return;

    builder.reset();
    _last = null;
    _hasFix = false;

    _startWall = DateTime.now();
    _elapsedSec = 0.0;

    await gps.start();

    _gpsSub = gps.stream.listen((s) {
      _last = s;
      _hasFix = true;
    }, onError: (e) {
      _out.addError(e);
    });

    _timer = Timer.periodic(Duration(seconds: resampleSeconds), (_) {
      final now = DateTime.now();
      _elapsedSec = now.difference(_startWall).inMilliseconds / 1000.0;

      if (!_hasFix || _last == null) return;

      // Use the most recent GPS sample
      final f = builder.updateFromGps(_last!);
      _out.add(f);
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;

    await _gpsSub?.cancel();
    _gpsSub = null;

    gps.stop();
  }

  void dispose() {
    stop();
    _out.close();
  }
}