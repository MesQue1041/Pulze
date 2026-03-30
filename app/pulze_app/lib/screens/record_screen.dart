import 'package:flutter/material.dart';

import '../core/settings_controller.dart';
import 'live_ride_screen.dart';

class RecordScreen extends StatefulWidget {
  final SettingsController settings;

  const RecordScreen({super.key, required this.settings});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  bool _launched = false;

  void _launch() {

    if (_launched || !mounted) return;

    setState(() => _launched = true);

    final s = widget.settings.settings;

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => LiveRideScreen(
          hrMax: s.hrMaxResolved,
          zoneUpperFrac: s.zoneUpperFracResolved,
          weightKg: s.weightKg,
          driftStartMinOverride: s.driftStartMin,
        ),
      ),
    )
        .then((_) {

      if (mounted) setState(() => _launched = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _launched ? null : _launch,
                child: AnimatedOpacity(
                  opacity: _launched ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFF7730), Color(0xFFCC3D00)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6820).withOpacity(0.4),
                          blurRadius: 32,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.fiber_manual_record_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'TAP TO RECORD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect HR strap and start your ride',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}