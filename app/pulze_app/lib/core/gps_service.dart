import 'dart:async';
import 'package:geolocator/geolocator.dart';

class GpsSample {
  final double tSec;
  final double lat;
  final double lon;
  final double speedMps;
  final double altitudeM;
  final double? accuracyM;

  GpsSample({
    required this.tSec,
    required this.lat,
    required this.lon,
    required this.speedMps,
    required this.altitudeM,
    required this.accuracyM,
  });
}

class GpsService {
  final StreamController<GpsSample> _ctrl = StreamController.broadcast();
  Stream<GpsSample> get stream => _ctrl.stream;

  StreamSubscription<Position>? _sub;
  final Stopwatch _sw = Stopwatch();
  bool _running = false;

  Future<bool> ensureReady() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return false;
    }
    if (perm == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;

    _sw
      ..reset()
      ..start();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      final t = _sw.elapsedMilliseconds / 1000.0;

      _ctrl.add(GpsSample(
        tSec: t,
        lat: pos.latitude,
        lon: pos.longitude,
        speedMps: (pos.speed.isFinite ? pos.speed : 0.0),
        altitudeM: (pos.altitude.isFinite ? pos.altitude : 0.0),
        accuracyM: pos.accuracy.isFinite ? pos.accuracy : null,
      ));
    });
  }

  void stop() {
    _running = false;
    _sw.stop();
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    stop();
    _ctrl.close();
  }
}
