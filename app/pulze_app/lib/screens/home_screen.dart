import 'dart:math';
import 'package:flutter/material.dart';

import '../core/settings_controller.dart';
import 'live_ride_screen.dart';
import 'demo_player_screen.dart';
import 'ride_history_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  final SettingsController settings;

  const HomeScreen({super.key, required this.settings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final s = widget.settings.settings;

        return Scaffold(
          backgroundColor: const Color(0xFF111111),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header bar ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                  child: Row(
                    children: [
                      _AnimatedHeart(anim: _pulseAnim),
                      const SizedBox(width: 10),
                      const Text(
                        "PULZE",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 5,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  SettingsScreen(controller: widget.settings),
                            )),
                        child: const Icon(Icons.settings_outlined,
                            color: Color(0xFF888888), size: 22),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Profile banner ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(child: _ProfileBanner(s: s)),
                ),

                const SizedBox(height: 18),

                // ── START RIDE hero button ───────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StartRideCard(
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => LiveRideScreen(
                            hrMax: s.hrMaxResolved,
                            zoneUpperFrac: s.zoneUpperFrac,
                            weightKg: s.weightKg,
                            driftStartMinOverride: s.driftStartMin,
                          ),
                        )),
                  ),
                ),

                const SizedBox(height: 18),

                // ── 3 quick tiles ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickTile(
                          icon: Icons.smart_display_outlined,
                          label: "Demo",
                          accent: const Color(0xFF4FC3F7),
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                            builder: (_) => DemoPlayerScreen(
                              hrMax: s.hrMaxResolved,
                              zoneUpperFrac: s.zoneUpperFrac,
                              weightKg: s.weightKg,
                              driftStartMinOverride: s.driftStartMin,
                            ),
                          )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickTile(
                          icon: Icons.bar_chart_rounded,
                          label: "History",
                          accent: const Color(0xFF81C784),
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                            builder: (_) => RideHistoryScreen(
                              hrMax: s.hrMaxResolved,
                              zoneUpperFrac: s.zoneUpperFrac,
                            ),
                          )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickTile(
                          icon: Icons.help_outline_rounded,
                          label: "Help",
                          accent: const Color(0xFFCE93D8),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const HelpScreen())),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Zone key card ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ZoneKeyCard(
                    hrMax: s.hrMaxResolved,
                    zoneUpperFrac: s.zoneUpperFrac,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated pulsing heart icon
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedHeart extends StatelessWidget {
  final Animation<double> anim;
  const _AnimatedHeart({required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Transform.scale(
        scale: anim.value,
        child: const Icon(Icons.favorite_rounded,
            color: Color(0xFFFF8C55), size: 26),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile banner
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileBanner extends StatelessWidget {
  final dynamic s;
  const _ProfileBanner({required this.s});

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline_rounded,
                color: Color(0xFF888888), size: 18),
            const SizedBox(width: 12),
            _chip("Age", "${s.age} yrs"),
            _divider(),
            _chip("HRmax", "${s.hrMaxResolved} bpm"),
            _divider(),
            _chip("Weight", "${s.weightKg.toStringAsFixed(0)} kg"),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _divider() => Container(
    height: 28,
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: const Color(0xFF2C2C2C),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero START RIDE card
// ─────────────────────────────────────────────────────────────────────────────
class _StartRideCard extends StatefulWidget {
  final VoidCallback onTap;
  const _StartRideCard({required this.onTap});

  @override
  State<_StartRideCard> createState() => _StartRideCardState();
}

class _StartRideCardState extends State<_StartRideCard> {
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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7730), Color(0xFFFF5500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6820).withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 24),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "START RIDE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Live HR zone tracking with drift correction",
                      style: TextStyle(
                        color: Color(0xFFFFD4B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFFFD4B8), size: 16),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick action tile
// ─────────────────────────────────────────────────────────────────────────────
class _QuickTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
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
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zone key card
// ─────────────────────────────────────────────────────────────────────────────
class _ZoneKeyCard extends StatelessWidget {
  final int hrMax;
  final List<double> zoneUpperFrac;

  const _ZoneKeyCard({required this.hrMax, required this.zoneUpperFrac});

  static const _zoneColors = [
    Color(0xFF5BC8F5),
    Color(0xFF81C784),
    Color(0xFFFFD54F),
    Color(0xFFFF8C55),
    Color(0xFFEF5350),
  ];
  static const _zoneLabels = ["Z1", "Z2", "Z3", "Z4", "Z5"];
  static const _zoneNames = [
    "Recovery", "Aerobic", "Tempo", "Threshold", "Max"
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bar_chart_rounded,
                  color: Color(0xFF888888), size: 16),
              SizedBox(width: 6),
              Text(
                "YOUR HR ZONES",
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(5, (i) {
            final lower =
            i == 0 ? 0 : (hrMax * zoneUpperFrac[i - 1]).round();
            final upper = (hrMax * zoneUpperFrac[i]).round();
            final fraction =
                zoneUpperFrac[i] - (i == 0 ? 0.0 : zoneUpperFrac[i - 1]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _zoneColors[i].withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _zoneLabels[i],
                      style: TextStyle(
                        color: _zoneColors[i],
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 72,
                    child: Text(
                      _zoneNames[i],
                      style: const TextStyle(
                        color: Color(0xFFAAAAAA),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction / 0.20,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _zoneColors[i]),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "$lower–$upper",
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}