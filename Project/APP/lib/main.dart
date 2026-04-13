import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'audio_service.dart';
import 'ble_service.dart';
import 'home_page.dart';
import 'models/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bleService = BleService();
  final audioService = AudioService();

  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => AppState(
        bleService: bleService,
        audioService: audioService,
      )..initialize(),
      child: const SportMusicApp(),
    ),
  );
}

class SportMusicApp extends StatelessWidget {
  const SportMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Sport Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF4F7F5),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
