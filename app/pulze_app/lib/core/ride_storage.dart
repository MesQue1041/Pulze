import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RideStorage {
  static const String folderName = "pulze_rides";

  static Future<Directory> _ridesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory("${base.path}/$folderName");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Create a new ride file path
  static Future<File> createNewRideFile() async {
    final dir = await _ridesDir();
    final ts = DateTime.now().toIso8601String().replaceAll(":", "-");
    return File("${dir.path}/ride_$ts.csv");
  }

  /// List all saved rides (newest first)
  static Future<List<File>> listRideFiles() async {
    final dir = await _ridesDir();
    final items = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith(".csv"))
        .cast<File>()
        .toList();

    items.sort((a, b) => b.path.compareTo(a.path));
    return items;
  }

  static Future<void> deleteRide(File f) async {
    if (await f.exists()) {
      await f.delete();
    }
  }
}
