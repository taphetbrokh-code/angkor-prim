import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models.dart';
import '../player/player_controller.dart';
import '../services/library_store.dart';
import '../services/yt_service.dart';
import 'common.dart';

/// The video area with YouTube-like overlay controls.
class PlayerView extends StatefulWidget {
  final bool fullscreen;
  const PlayerView({super.key, this.fullscreen = false});

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  bool _show = true;
  Timer? _hide;
  double? _drag; // slider value while dragging (ms)
  String? _seekFlash;
  TapDownDetails? _lastDown;

  PlayerController get p => PlayerController.instance;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && p.audio.playing && _drag == null) {
        setState(() => _show = false);
      }
    });
  }

  void _toggle() {
    setState(() => _show = !_show);
    if (_show) _scheduleHide();
  }

  void _doubleTap(TapDownDetails d, double width) {
    final forward = d.localPosition.dx > width / 2;
    p.seekRelative(forward ? 10 : -10);
    setState(() => _seekFlash = forward ? '+10s' : '-10s');
    Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekFlash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content() => LayoutBuilder(builder: (context, box) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onDoubleTapDown: (d) => _lastDown = d,
        onDoubleTap: () {
          final d = _lastDown;
          if (d != null) _doubleTap(d, box.maxWidth);
        },
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Colors.black),
          _picture(),
          if (_seekFlash != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(_seekFlash!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
          AnimatedOpacity(
            opacity: _show ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(ignoring: !_show, child: _controls()),
          ),
          if (!_show) Positioned(left: 0, right: 0, bottom: 0, child: _thinBar()),
        ]),
      );
    });

    final live = ListenableBuilder(
      listenable: Listenable.merge([p, LibraryStore.instance]),
      builder: (_, __) => content(),
    );
    if (widget.fullscreen) return live;
    return AspectRatio(aspectRatio: 16 / 9, child: live);
  }

  Widget _picture() {
    final v = p.current;
    final vc = p.video;
    if (vc != null && vc.value.isInitialized) {
      return Center(
        child: AspectRatio(aspectRatio: vc.value.aspectRatio, child: VideoPlayer(vc)),
      );
    }
    return Stack(fit: StackFit.expand, children: [
      if (v != null) Opacity(opacity: 0.55, child: NetImage(v.thumb, fit: BoxFit.contain)),
      if (p.error != null)
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(p.error!,
                  maxLines: 12,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: p.retry, child: const Text('ព្យាយាមម្តងទៀត')),
            ]),
          ),
        )
      else if (LibraryStore.instance.audioOnly && !p.loading)
        const Align(
          alignment: Alignment(0, 0.55),
          child: Chip(
            avatar: Icon(Icons.headphones, size: 16),
            label: Text('របៀបស្តាប់តែសំឡេង', style: TextStyle(fontSize: 12)),
          ),
        )
      else if (p.loading || p.videoLoading)
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: kAccent),
            const SizedBox(height: 70),
            ValueListenableBuilder<String>(
              valueListenable: YtService.status,
              builder: (_, s, __) => Text(s,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ),
          ]),
        ),
    ]);
  }

  Widget _thinBar() {
    return StreamBuilder<Duration>(
      stream: p.audio.positionStream,
      builder: (c, snap) {
        final dur = p.audio.duration ?? p.current?.duration ?? Duration.zero;
        final pos = snap.data ?? Duration.zero;
        final v = dur.inMilliseconds > 0
            ? clampD(pos.inMilliseconds / dur.inMilliseconds, 0.0, 1.0)
            : 0.0;
        return LinearProgressIndicator(
            value: v, minHeight: 2, color: kAccent, backgroundColor: Colors.white24);
      },
    );
  }

  Widget _controls() {
    return Container(
      color: Colors.black38,
      child: SafeArea(
        top: widget.fullscreen,
        bottom: false,
        child: Column(children: [
          // ---- top bar ----
          Row(children: [
            if (!widget.fullscreen)
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                onPressed: p.minimize,
              )
            else
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => p.setFullscreen(false),
              ),
            if (widget.fullscreen)
              Expanded(
                child: Text(p.current?.title ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              )
            else
              const Spacer(),
            IconButton(
              tooltip: 'ស្តាប់តែសំឡេង',
              icon: Icon(LibraryStore.instance.audioOnly
                  ? Icons.headphones
                  : Icons.headphones_outlined),
              color: LibraryStore.instance.audioOnly ? kAccent : null,
              onPressed: () => p.setAudioOnly(!LibraryStore.instance.audioOnly),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => showPlayerSettings(context),
            ),
          ]),
          const Spacer(),
          // ---- center buttons ----
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_previous),
              onPressed: () {
                p.prev();
                _scheduleHide();
              },
            ),
            StreamBuilder<PlayerState>(
              stream: p.audio.playerStateStream,
              builder: (c, snap) {
                final s = snap.data;
                final busy = p.loading ||
                    s?.processingState == ProcessingState.loading ||
                    s?.processingState == ProcessingState.buffering;
                if (busy) {
                  return const SizedBox(
                      width: 56,
                      height: 56,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(color: Colors.white),
                      ));
                }
                final playing = s?.playing ?? false;
                final done = s?.processingState == ProcessingState.completed;
                return IconButton(
                  iconSize: 56,
                  icon: Icon(done
                      ? Icons.replay
                      : playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled),
                  onPressed: () {
                    p.togglePlay();
                    _scheduleHide();
                  },
                );
              },
            ),
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_next),
              onPressed: () {
                p.next();
                _scheduleHide();
              },
            ),
          ]),
          const Spacer(),
          // ---- bottom bar ----
          StreamBuilder<Duration>(
            stream: p.audio.positionStream,
            builder: (c, snap) {
              final dur = p.audio.duration ?? p.current?.duration ?? Duration.zero;
              final pos = snap.data ?? Duration.zero;
              final max = dur.inMilliseconds < 1 ? 1.0 : dur.inMilliseconds.toDouble();
              final value = clampD(_drag ?? pos.inMilliseconds.toDouble(), 0.0, max);
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Text(
                      '${fmtDuration(Duration(milliseconds: value.toInt()))} / ${fmtDuration(dur)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(widget.fullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                      onPressed: () => p.setFullscreen(!widget.fullscreen),
                    ),
                  ]),
                ),
                SizedBox(
                  height: 18,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: kAccent,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: kAccent,
                    ),
                    child: Slider(
                      value: value,
                      max: max,
                      onChangeStart: (v) {
                        _hide?.cancel();
                        setState(() => _drag = v);
                      },
                      onChanged: (v) => setState(() => _drag = v),
                      onChangeEnd: (v) {
                        p.seek(Duration(milliseconds: v.toInt()));
                        setState(() => _drag = null);
                        _scheduleHide();
                      },
                    ),
                  ),
                ),
                SizedBox(height: widget.fullscreen ? 12 : 2),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

Future<void> showPlayerSettings(BuildContext context) {
  final p = PlayerController.instance;
  final lib = LibraryStore.instance;
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      listenable: Listenable.merge([p, lib]),
      builder: (ctx, _) {
        final opts = p.streams?.videos ?? const <VideoOption>[];
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: const Icon(Icons.high_quality_outlined),
                title: const Text('គុណភាព'),
                trailing: Text(lib.audioOnly ? 'សំឡេងតែប៉ុណ្ណោះ' : (p.selected?.label ?? '-')),
                onTap: opts.isEmpty
                    ? null
                    : () => showModalBottomSheet(
                          context: ctx,
                          builder: (c2) => SafeArea(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              for (final o in opts)
                                ListTile(
                                  title: Text(o.label),
                                  trailing: p.selected?.url == o.url && !lib.audioOnly
                                      ? const Icon(Icons.check, color: kAccent)
                                      : null,
                                  onTap: () {
                                    Navigator.pop(c2);
                                    if (lib.audioOnly) p.setAudioOnly(false);
                                    p.setQuality(o);
                                  },
                                ),
                              ListTile(
                                leading: const Icon(Icons.headphones),
                                title: const Text('ស្តាប់តែសំឡេង (សន្សំ data)'),
                                trailing: lib.audioOnly
                                    ? const Icon(Icons.check, color: kAccent)
                                    : null,
                                onTap: () {
                                  Navigator.pop(c2);
                                  p.setAudioOnly(true);
                                },
                              ),
                            ]),
                          ),
                        ),
              ),
              ListTile(
                leading: const Icon(Icons.slow_motion_video),
                title: const Text('ល្បឿនចាក់'),
                trailing: Text(p.speed == 1.0 ? 'ធម្មតា' : '${p.speed}x'),
                onTap: () => showModalBottomSheet(
                  context: ctx,
                  builder: (c2) => SafeArea(
                    child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final s in const [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
                          ListTile(
                            title: Text(s == 1.0 ? 'ធម្មតា' : '${s}x'),
                            trailing: p.speed == s
                                ? const Icon(Icons.check, color: kAccent)
                                : null,
                            onTap: () {
                              Navigator.pop(c2);
                              p.setSpeed(s);
                            },
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.repeat_one),
                title: const Text('ចាក់ដដែលៗ (Loop)'),
                value: p.loop,
                onChanged: (_) => p.toggleLoop(),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.skip_next_outlined),
                title: const Text('ចាក់បន្តស្វ័យប្រវត្តិ (Autoplay)'),
                value: lib.autoplay,
                onChanged: lib.setAutoplay,
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('កំណត់ម៉ោងបិទ (Sleep timer)'),
                trailing: Text(p.sleepAt == null
                    ? 'បិទ'
                    : 'នៅ ${TimeOfDay.fromDateTime(p.sleepAt!).format(ctx)}'),
                onTap: () => showModalBottomSheet(
                  context: ctx,
                  builder: (c2) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final m in const [0, 10, 15, 30, 45, 60, 90])
                        ListTile(
                          title: Text(m == 0 ? 'បិទ' : '$m នាទី'),
                          onTap: () {
                            Navigator.pop(c2);
                            p.setSleep(m == 0 ? null : Duration(minutes: m));
                          },
                        ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    ),
  );
}
