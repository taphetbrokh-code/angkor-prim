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
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.angkorprim.app.audio',
    androidNotificationChannelName: 'ANGKOR PRIM',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_notification',
  );
  await LibraryStore.instance.init();
  // create the player early so it observes lifecycle from the start
  PlayerController.instance;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const AngkorPrimApp());
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
