import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'player/player_controller.dart';
import 'screens/shell.dart';
import 'services/library_store.dart';

const kAccent = Color(0xFFE8A33D); // Angkor gold
const kAccentDeep = Color(0xFFC0392B);
const kBg = Color(0xFF0F0F0F);
const kSurface = Color(0xFF1C1C1C);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];

  // Never let a start-up step hang or crash the app (that shows a black screen).
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.angkorprim.app.audio',
      androidNotificationChannelName: 'ANGKOR PRIM',
      androidNotificationOngoing: true,
    ).timeout(const Duration(seconds: 8));
  } catch (e) {
    errors.add('Audio service: $e');
  }
  try {
    await LibraryStore.instance.init().timeout(const Duration(seconds: 5));
  } catch (e) {
    errors.add('Storage: $e');
  }
  try {
    // create the player early so it observes lifecycle from the start
    PlayerController.instance;
  } catch (e) {
    errors.add('Player: $e');
  }
  try {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (_) {}

  // Show build errors as readable text instead of a blank screen.
  ErrorWidget.builder = (details) => Material(
        color: kBg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(details.exceptionAsString(),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
      );

  runApp(errors.isEmpty ? const AngkorPrimApp() : StartupErrorApp(errors));
}

class StartupErrorApp extends StatelessWidget {
  final List<String> errors;
  const StartupErrorApp(this.errors, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('ANGKOR PRIM',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kAccent)),
            const SizedBox(height: 12),
            const Text('មានបញ្ហាពេលចាប់ផ្តើម — សូម screenshot ទំព័រនេះផ្ញើមក:',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            for (final e in errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText(e,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
          ]),
        ),
      ),
    );
  }
}

class AngkorPrimApp extends StatelessWidget {
  const AngkorPrimApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kAccent,
      brightness: Brightness.dark,
      primary: kAccent,
      surface: kBg,
    );
    return MaterialApp(
      title: 'ANGKOR PRIM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kBg,
          indicatorColor: Colors.white12,
          height: 62,
          labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, color: Colors.white)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: kSurface,
          surfaceTintColor: Colors.transparent,
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: Color(0xFF272727),
          side: BorderSide.none,
          labelStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const Shell(),
    );
  }
}
