import 'package:flutter/material.dart';
import '../core/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool advancedOpen = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.controller.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),

          _sliderTile(
            title: 'Age',
            valueText: '${s.age} years',
            value: s.age.toDouble(),
            min: 12,
            max: 70,
            divisions: 58,
            onChanged: (v) {
              widget.controller.setAge(v.round());
              setState(() {});
            },
          ),

          _sliderTile(
            title: 'Weight',
            valueText: '${s.weightKg.toStringAsFixed(1)} kg',
            value: s.weightKg,
            min: 40,
            max: 120,
            divisions: 160,
            onChanged: (v) {
              widget.controller.setWeightKg(v);
              setState(() {});
            },
          ),

          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),

          const Text('Heart Rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),

          SwitchListTile(
            value: s.useDefaultHrMax,
            onChanged: (v) {
              widget.controller.setUseDefaultHrMax(v);
              setState(() {});
            },
            title: const Text('Use default HRmax (220 − age)'),
            subtitle: Text('Current HRmax: ${s.hrMaxResolved} bpm'),
          ),

          if (!s.useDefaultHrMax)
            _sliderTile(
              title: 'Custom HRmax',
              valueText: '${s.customHrMax.toStringAsFixed(0)} bpm',
              value: s.customHrMax,
              min: 140,
              max: 230,
              divisions: 90,
              onChanged: (v) {
                widget.controller.setCustomHrMax(v);
                setState(() {});
              },
            ),

          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),

          const Text('Zones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),

          SwitchListTile(
            value: s.useCustomZones,
            onChanged: (v) {
              widget.controller.setUseCustomZones(v);
              setState(() {});
            },
            title: const Text('Enable custom zones (optional)'),
            subtitle: Text(
              s.useCustomZones
                  ? 'Custom zones enabled'
                  : 'Using default 5-zone scheme',
            ),
          ),

          if (s.useCustomZones) ...[
            const SizedBox(height: 6),
            _zoneEditor(s),
          ],

          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),

          // Advanced (collapsed by default)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => advancedOpen = !advancedOpen),
            child: Row(
              children: [
                const Text('Advanced', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                Icon(advancedOpen ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),

          if (advancedOpen) ...[
            const SizedBox(height: 10),
            _sliderTile(
              title: 'Drift correction start',
              valueText: '${s.driftStartMin} min (default: 20)',
              value: s.driftStartMin.toDouble(),
              min: 5,
              max: 40,
              divisions: 35,
              onChanged: (v) {
                widget.controller.setDriftStartMin(v.round());
                setState(() {});
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'Tip: You usually don’t need to change this.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sliderTile({
    required String title,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(valueText, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _zoneEditor(PulzeSettings s) {
    // Expect 5 values: Z1..Z5 upper bounds (fractions of HRmax)
    final z = List<double>.from(s.zoneUpperFrac);

    Widget oneRow(int idx, String label, double min, double max) {
      return _sliderTile(
        title: label,
        valueText: '${(z[idx] * 100).toStringAsFixed(0)}% HRmax',
        value: z[idx],
        min: min,
        max: max,
        divisions: ((max - min) * 100).round(),
        onChanged: (v) {
          z[idx] = v;

          // Keep monotonic increasing and clamp last to 1.0
          for (int i = 1; i < z.length; i++) {
            if (z[i] < z[i - 1]) z[i] = z[i - 1];
          }
          z[4] = 1.0;

          widget.controller.setZoneUpperFrac(z);
          setState(() {});
        },
      );
    }

    return Column(
      children: [
        oneRow(0, 'Zone 1 upper', 0.40, 0.80),
        oneRow(1, 'Zone 2 upper', 0.50, 0.90),
        oneRow(2, 'Zone 3 upper', 0.60, 0.95),
        oneRow(3, 'Zone 4 upper', 0.70, 0.99),
        // Zone 5 upper is always 1.0 in most schemes so we keep it locked
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            children: const [
              Expanded(child: Text('Zone 5 upper', style: TextStyle(fontWeight: FontWeight.w700))),
              Text('100% HRmax', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}