import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../player/player_controller.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
import 'home.dart';
import 'library.dart';
import 'music.dart';
import 'subscriptions.dart';
import 'watch.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  static const _roots = <Widget>[
    HomeScreen(),
    MusicScreen(),
    SubscriptionsScreen(),
    LibraryScreen(),
  ];

  void _onBack() {
    final p = PlayerController.instance;
    if (p.fullscreen) {
      p.setFullscreen(false);
      return;
    }
    if (p.expanded) {
      p.minimize();
      return;
    }
    final nav = AppNav.keys[_tab].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }
    if (_tab != 0) {
      _select(0);
      return;
    }
    SystemNavigator.pop();
  }

  void _select(int i) {
    if (i == _tab) {
      // tap again on the current tab: go back to its root
      AppNav.keys[i].currentState?.popUntil((r) => r.isFirst);
    }
    setState(() => _tab = i);
    AppNav.tab = i;
    PlayerController.instance.minimize();
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerController.instance;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: ListenableBuilder(
        listenable: p,
        builder: (context, _) {
          final showWatch = p.current != null && p.expanded;
          return Stack(children: [
            Scaffold(
              body: IndexedStack(
                index: _tab,
                children: [
                  for (var i = 0; i < _roots.length; i++)
                    Navigator(
                      key: AppNav.keys[i],
                      onGenerateRoute: (_) =>
                          MaterialPageRoute(builder: (_) => _roots[i]),
                    ),
                ],
              ),
              bottomNavigationBar: p.fullscreen
                  ? null
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      if (p.current != null && !p.expanded) const MiniPlayer(),
                      NavigationBar(
                        selectedIndex: _tab,
                        onDestinationSelected: _select,
                        destinations: const [
                          NavigationDestination(
                              icon: Icon(Icons.home_outlined),
                              selectedIcon: Icon(Icons.home),
                              label: 'ទំព័រដើម'),
                          NavigationDestination(
                              icon: Icon(Icons.music_note_outlined),
                              selectedIcon: Icon(Icons.music_note),
                              label: 'តន្ត្រី'),
                          NavigationDestination(
                              icon: Icon(Icons.subscriptions_outlined),
                              selectedIcon: Icon(Icons.subscriptions),
                              label: 'ការជាវ'),
                          NavigationDestination(
                              icon: Icon(Icons.video_library_outlined),
                              selectedIcon: Icon(Icons.video_library),
                              label: 'បណ្ណាល័យ'),
                        ],
                      ),
                    ]),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !showWatch,
                child: AnimatedSlide(
                  offset: showWatch ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: showWatch ? const WatchScreen() : const SizedBox.shrink(),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
