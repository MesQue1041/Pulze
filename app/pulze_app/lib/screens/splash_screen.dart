import 'dart:async';
import 'package:flutter/material.dart';

import '../core/settings_controller.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  final SettingsController settings;

  const SplashScreen({super.key, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 900), _go);
  }

  void _go() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(settings: widget.settings),
      ),
    );
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.directions_bike, size: 64),
            SizedBox(height: 12),
            Text(
              "Pulze",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text("Adaptive Heart Rate Zones"),
          ],
        ),
      ),
    );
  }
}