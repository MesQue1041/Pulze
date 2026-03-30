import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const PulzeApp());
}

class PulzeApp extends StatelessWidget {
  const PulzeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulze',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AppShell(),
    );
  }

  ThemeData _buildTheme() {
    const orange = Color(0xFFFF6B35);
    const orangeDim = Color(0xFFD4541F);
    const bg = Color(0xFF050505);
    const surface = Color(0xFF111111);
    const surface2 = Color(0xFF1A1A1A);
    const border = Color(0xFF2A2A2A);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        brightness: Brightness.dark,
        primary: orange,
        onPrimary: Colors.black,
        primaryContainer: const Color(0xFF2A1800),
        onPrimaryContainer: orange,
        secondary: orangeDim,
        onSecondary: Colors.black,
        secondaryContainer: const Color(0xFF1F1000),
        onSecondaryContainer: orange,
        surface: surface,
        onSurface: Colors.white,
        surfaceContainerHighest: surface2,
        onSurfaceVariant: const Color(0xFF9E9E9E),
        outline: border,
        outlineVariant: border,
        error: const Color(0xFFFF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: const Color(0xFF2A1800),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: orange);
          }
          return const IconThemeData(color: Color(0xFF6E6E6E));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: orange,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: Color(0xFF6E6E6E),
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.black,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: orange,
          side: const BorderSide(color: Color(0xFF2A2A2A)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: orange,
        thumbColor: orange,
        inactiveTrackColor: Color(0xFF2A2A2A),
        overlayColor: Color(0x33FF6B35),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.black;
          return const Color(0xFF555555);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return orange;
          return const Color(0xFF2A2A2A);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1E1E1E),
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Color(0xFFB0B0B0)),
        labelSmall: TextStyle(color: Color(0xFF6E6E6E)),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: Colors.white,
        iconColor: Color(0xFF9E9E9E),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}