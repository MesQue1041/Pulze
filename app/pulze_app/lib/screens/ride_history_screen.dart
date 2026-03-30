import 'dart:io';
import 'package:flutter/material.dart';

import '../core/ride_storage.dart';
import 'ride_details_screen.dart';

class RideHistoryScreen extends StatefulWidget {
  final int hrMax;
  final List<double> zoneUpperFrac;

  const RideHistoryScreen({
    super.key,
    required this.hrMax,
    required this.zoneUpperFrac,
  });

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  bool _loading = true;
  String? _err;
  List<File> _rides = [];

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final files = await RideStorage.listRideFiles();
      if (!mounted) return;
      setState(() {
        _rides = files;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteRide(File f, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete ride?',
            style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: Color(0xFF888888))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFEF5350))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await RideStorage.deleteRide(f);
    setState(() => _rides.removeAt(index));
  }


  String _parseRideDate(String filename) {
    try {
      final core = filename
          .replaceFirst('ride_', '')
          .replaceAll('.csv', '');


      if (RegExp(r'^\d{8}_\d{6}$').hasMatch(core)) {
        final d = core.substring(0, 8);
        final t = core.substring(9);
        final year  = int.parse(d.substring(0, 4));
        final month = int.parse(d.substring(4, 6));
        final day   = int.parse(d.substring(6, 8));
        final hour  = int.parse(t.substring(0, 2));
        final min   = int.parse(t.substring(2, 4));
        const months = ['Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
        return '${months[month - 1]} $day  ·  '
            '${hour.toString().padLeft(2,'0')}:${min.toString().padLeft(2,'0')}';
      }


      final parts = core.split('T');
      if (parts.length >= 2) {
        final datePart = parts[0];
        final timePart = parts[1].split('.').first;
        final dt = DateTime.tryParse(
            '${datePart}T${timePart.replaceAll('-', ':')}');
        if (dt != null) {
          const months = ['Jan','Feb','Mar','Apr','May','Jun',
            'Jul','Aug','Sep','Oct','Nov','Dec'];
          return '${months[dt.month - 1]} ${dt.day}  ·  '
              '${dt.hour.toString().padLeft(2,'0')}:'
              '${dt.minute.toString().padLeft(2,'0')}';
        }
      }

      return filename;
    } catch (_) {
      return filename;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text(
          'HISTORY',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
        actions: [
          IconButton(
            onPressed: _loadRides,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF888888)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8C55)))
          : _err != null
          ? _errorState()
          : _rides.isEmpty
          ? _emptyState()
          : _rideList(),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF5350), size: 48),
            const SizedBox(height: 12),
            const Text('Could not load rides',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(_err ?? '',
                style: const TextStyle(
                    color: Color(0xFF888888), fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRides,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: const Icon(Icons.directions_bike_outlined,
                color: Color(0xFF444444), size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No rides yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Complete your first ride to see it here',
              style: TextStyle(color: Color(0xFF666666), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _rideList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _rides.length,
      itemBuilder: (_, i) {
        final f = _rides[i];
        final filename = f.path.split('/').last;
        final dateLabel = _parseRideDate(filename);
        final rideNumber = _rides.length - i;

        return _RideTile(
          rideNumber: rideNumber,
          filename: filename,
          dateLabel: dateLabel,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RideDetailsScreen(
                  filePath: f.path,
                  hrMax: widget.hrMax,
                  zoneUpperFrac: widget.zoneUpperFrac,
                ),
              ),
            );

            _loadRides();
          },
          onDelete: () => _deleteRide(f, i),
        );
      },
    );
  }
}


// Single ride tile

class _RideTile extends StatefulWidget {
  final int rideNumber;
  final String filename;
  final String dateLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RideTile({
    required this.rideNumber,
    required this.filename,
    required this.dateLabel,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_RideTile> createState() => _RideTileState();
}

class _RideTileState extends State<_RideTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Row(
            children: [
              // Ride number badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C55).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${widget.rideNumber}',
                  style: const TextStyle(
                      color: Color(0xFFFF8C55),
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              // Date + filename
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.dateLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(widget.filename,
                        style: const TextStyle(
                            color: Color(0xFF555555), fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Delete button
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFF444444), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF444444), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}