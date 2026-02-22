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
  bool loading = true;
  String? err;
  List<File> rides = [];

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    try {
      final files = await RideStorage.listRideFiles();
      setState(() {
        rides = files;
        loading = false;
      });
    } catch (e) {
      setState(() {
        err = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride History"),
        actions: [
          IconButton(onPressed: _loadRides, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : err != null
          ? Padding(padding: const EdgeInsets.all(16), child: Text("Error: $err"))
          : ListView.builder(
        itemCount: rides.length,
        itemBuilder: (_, i) {
          final f = rides[i];
          final name = f.path.split("/").last;
          return ListTile(
            title: Text(name),
            subtitle: Text(f.path),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RideDetailsScreen(
                    filePath: f.path,
                    hrMax: widget.hrMax,
                    zoneUpperFrac: widget.zoneUpperFrac,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}