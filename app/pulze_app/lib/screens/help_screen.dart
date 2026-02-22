import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _StepCard(
            step: '1',
            title: 'Connect HR strap',
            text: 'Open Record → Start Live Ride → Scan → Tap your HR device to connect.',
          ),
          _StepCard(
            step: '2',
            title: 'Start Ride',
            text: 'Once connected, press Start. Your Effective HR will be shown in the large circle.',
          ),
          _StepCard(
            step: '3',
            title: 'What is drift correction?',
            text:
            'During long steady riding, heart rate drifts upward even if effort stays constant. '
                'Pulze estimates drift and subtracts it to produce Effective HR, improving zone interpretation.',
          ),
          _StepCard(
            step: '4',
            title: 'After the ride',
            text: 'Stop → Post Ride Summary shows charts, time-in-zone (Raw vs Effective), and drift stats.',
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final String text;

  const _StepCard({required this.step, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            alignment: Alignment.center,
            child: Text(step, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(text, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}