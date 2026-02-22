import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'ride_row.dart';

class RideLoader {
  static List<RideRow> _parseCsv(String raw) {
    final rows = const CsvToListConverter(eol: '\n').convert(raw);

    if (rows.isEmpty) {
      throw StateError("CSV is empty.");
    }

    final header = rows.first.map((e) => e.toString().trim()).toList();

    int idxAny(List<String> names) {
      for (final n in names) {
        final i = header.indexOf(n);
        if (i >= 0) return i;
      }
      return -1;
    }

    final iT = idxAny(['elapsed_seconds', 't', 'time_s']);
    final iHr = idxAny(['hr', 'heart_rate']);
    final iP = idxAny(['P_used', 'p_used']);
    final iP60 = idxAny(['P_used_roll_60s', 'p_used_roll_60s']);
    final iSp = idxAny(['speed_kmh_clean', 'speed_kmh', 'speed']);
    final iGr = idxAny(['grade_roll_2m', 'grade']);
    final iCorr = idxAny(['corr_active', 'corr']);

    final requiredIdx = {
      'elapsed_seconds': iT,
      'hr': iHr,
      'P_used': iP,
      'P_used_roll_60s': iP60,
      'speed_kmh_clean': iSp,
      'grade_roll_2m': iGr,
      'corr_active': iCorr,
    };

    final missing = requiredIdx.entries.where((e) => e.value < 0).map((e) => e.key).toList();
    if (missing.isNotEmpty) {
      throw StateError(
        "CSV missing required columns: ${missing.join(', ')}\n"
            "Found header: $header",
      );
    }

    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      final s = v.toString();
      return double.tryParse(s) ?? 0.0;
    }

    int asInt(dynamic v) {
      if (v is num) return v.toInt();
      final s = v.toString();
      return int.tryParse(s) ?? 0;
    }

    final out = <RideRow>[];
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.length < header.length) continue;

      out.add(RideRow(
        tSec: asDouble(row[iT]),
        hr: asDouble(row[iHr]),
        pUsed: asDouble(row[iP]),
        pUsed60: asDouble(row[iP60]),
        speedKmh: asDouble(row[iSp]),
        grade2m: asDouble(row[iGr]),
        corrActive: asInt(row[iCorr]),
      ));
    }

    if (out.isEmpty) {
      throw StateError("No data rows parsed from CSV.");
    }

    return out;
  }

  static Future<List<RideRow>> loadDemoCsv(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return _parseCsv(raw);
  }

  static Future<List<RideRow>> loadCsvFile(String filePath) async {
    final f = File(filePath);
    if (!await f.exists()) {
      throw StateError("Ride file not found: $filePath");
    }
    final raw = await f.readAsString();
    return _parseCsv(raw);
  }

  static Future<Map<String, dynamic>> loadJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
