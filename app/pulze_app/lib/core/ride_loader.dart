import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

import 'package:pulze_app/core/ride_row.dart';

class RideLoader {
  static List<RideRow> parseCsv(String raw) {
    final rows = const CsvToListConverter(eol: '\n').convert(raw);
    if (rows.isEmpty) throw StateError('CSV is empty.');

    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    int idxAny(List<String> names) {
      for (final n in names) {
        final i = header.indexOf(n.toLowerCase());
        if (i >= 0) return i;
      }
      return -1;
    }


    final iT   = idxAny(['elapsedseconds', 'elapsed_seconds', 't', 'time', 'times']);
    final iHr  = idxAny(['hr', 'heartrate', 'heart_rate']);
    final iP   = idxAny(['pused', 'p_used', 'pvirtual', 'p_virtual']);
    final iP60 = idxAny(['pusedroll60s', 'p_used_roll_60s', 'pvirtual60s', 'p_virtual_60s']);
    final iSp  = idxAny(['speedkmhclean', 'speed_kmh_clean', 'speedkmh', 'speed_kmh', 'speed']);
    final iGr  = idxAny(['graderoll2m', 'grade_roll_2m', 'graderoll120s', 'grade_roll_120s', 'grade']);
    final iCorr= idxAny(['corractive', 'corr_active', 'corr']);

    final requiredIdx = {
      'elapsedseconds': iT,
      'hr':             iHr,
      'Pused/Pvirtual': iP,
      'Pusedroll60s':   iP60,
      'speedkmhclean':  iSp,
      'graderoll2m':    iGr,
      'corractive':     iCorr,
    };

    final missing = requiredIdx.entries.where((e) => e.value < 0).map((e) => e.key).toList();
    if (missing.isNotEmpty) {
      throw StateError(
        'CSV missing required columns: ${missing.join(', ')}. '
            'Found header: $header',
      );
    }

    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().trim()) ?? 0.0;
    }

    int asInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v.toString().trim()) ?? 0;
    }

    final out = <RideRow>[];
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.length < header.length) continue;
      out.add(RideRow(
        tSec:       asDouble(row[iT]),
        hr:         asDouble(row[iHr]),
        pUsed:      asDouble(row[iP]),
        pUsed60:    asDouble(row[iP60]),
        speedKmh:   asDouble(row[iSp]),
        grade2m:    asDouble(row[iGr]),
        corrActive: asInt(row[iCorr]),
      ));
    }

    if (out.isEmpty) throw StateError('No data rows parsed from CSV.');
    return out;
  }

  static Future<List<RideRow>> loadDemoCsv(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return parseCsv(raw);
  }

  static Future<List<RideRow>> loadCsvFile(String filePath) async {
    final f = File(filePath);
    if (!await f.exists()) throw StateError('Ride file not found: $filePath');
    final raw = await f.readAsString();
    return parseCsv(raw);
  }

  static Future<Map<String, dynamic>> loadJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}