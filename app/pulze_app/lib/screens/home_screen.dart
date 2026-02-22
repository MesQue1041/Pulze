import 'package:flutter/material.dart';

import '../core/settings_controller.dart';
import 'live_ride_screen.dart';
import 'demo_player_screen.dart';
import 'ride_history_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatelessWidget {
  final SettingsController settings;

  const HomeScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final s = settings.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pulze"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsScreen(controller: settings)),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _header(s),
            const SizedBox(height: 14),

            _bigButton(
              context,
              icon: Icons.play_arrow,
              title: "Start Ride",
              subtitle: "Observed vs Effective HR in real time",
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LiveRideScreen(
                      hrMax: s.hrMaxResolved,
                      zoneUpperFrac: s.zoneUpperFrac,
                      weightKg: s.weightKg,
                      driftStartMinOverride: s.driftStartMin,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _tileButton(
                    context,
                    icon: Icons.history,
                    title: "History",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RideHistoryScreen(
                            hrMax: s.hrMaxResolved,
                            zoneUpperFrac: s.zoneUpperFrac,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _tileButton(
                    context,
                    icon: Icons.smart_display,
                    title: "Demo Player",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DemoPlayerScreen(
                            hrMax: s.hrMaxResolved,
                            zoneUpperFrac: s.zoneUpperFrac,
                            weightKg: s.weightKg,
                            driftStartMinOverride: s.driftStartMin,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _tileButton(
                    context,
                    icon: Icons.tune,
                    title: "Settings",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SettingsScreen(controller: settings)),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _tileButton(
                    context,
                    icon: Icons.help_outline,
                    title: "Help",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.favorite, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Training Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text("HRmax: ${s.hrMaxResolved} bpm  •  Drift starts: ${s.driftStartMin} min"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigButton(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 34),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _tileButton(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}