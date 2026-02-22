import 'package:flutter/material.dart';

import '../core/settings_controller.dart';
import 'live_ride_screen.dart';
import 'demo_player_screen.dart';
import 'help_screen.dart';

class RecordScreen extends StatelessWidget {
  final SettingsController settings;

  const RecordScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final s = settings.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _bigActionCard(
              context,
              title: 'Start Live Ride',
              subtitle: 'Connect HR strap and ride',
              icon: Icons.fiber_manual_record,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveRideScreen(
                      hrMax: s.hrMaxResolved,
                      zoneUpperFrac: s.zoneUpperFracResolved,
                      weightKg: s.weightKg,
                      driftStartMinOverride: s.driftStartMin,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _bigActionCard(
              context,
              title: 'Demo Ride Player',
              subtitle: 'Replay demo ride',
              icon: Icons.play_circle_outline,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DemoPlayerScreen(
                      hrMax: s.hrMaxResolved,
                      zoneUpperFrac: s.zoneUpperFracResolved,
                      weightKg: s.weightKg,
                      driftStartMinOverride: s.driftStartMin,
                    ),
                  ),
                );
              },
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _bigActionCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}