import 'package:flutter/material.dart';

import '../core/settings_controller.dart';
import 'home_screen.dart';
import 'record_screen.dart';
import 'ride_history_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _idx = 0;

  late final SettingsController _settings = SettingsController();

  @override
  Widget build(BuildContext context) {
    final s = _settings.settings;

    final pages = <Widget>[
      HomeScreen(settings: _settings),
      RecordScreen(settings: _settings),
      RideHistoryScreen(
        hrMax: s.hrMaxResolved,
        zoneUpperFrac: s.zoneUpperFrac,
      ),
      SettingsScreen(controller: _settings),
    ];

    return Scaffold(
      body: IndexedStack(index: _idx, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (v) => setState(() => _idx = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.fiber_manual_record_outlined), selectedIcon: Icon(Icons.fiber_manual_record), label: 'Record'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}