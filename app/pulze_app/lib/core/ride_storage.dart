import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RideStorage {
  static const String folderName = 'pulze_rides';

  static Future<Directory> ridesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$folderName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> createNewRideFile() async {
    final dir = await ridesDir();
    final now = DateTime.now();


    final ts =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    return File('${dir.path}/ride_$ts.csv');
  }

  static Future<List<File>> listRideFiles() async {
    final dir = await ridesDir();
    final items = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.csv'))
        .cast<File>()
        .toList();
    items.sort((a, b) => b.path.compareTo(a.path));
    return items;
  }

  static Future<void> deleteRide(File f) async {
    if (await f.exists()) await f.delete();
  }
}