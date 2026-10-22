import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../services/library_store.dart';
import '../services/yt_service.dart';

/// The single playback engine of the app.
///
/// How background play works:
///  * The AUDIO stream is played by just_audio inside a foreground media
///    service (just_audio_background). It is the master clock and keeps
///    playing when the app is minimised or the screen is turned off. It also
///    shows the lock-screen / notification controls.
///  * The VIDEO (picture only, muted) is played by video_player and kept in
///    sync with the audio. When the app goes to the background the video is
///    released; when the app comes back it is re-created at the audio
///    position.
class PlayerController extends ChangeNotifier with WidgetsBindingObserver {
  PlayerController._() {
    WidgetsBinding.instance.addObserver(this);
    audio.playerStateStream.listen(_onAudioState);
    _syncTimer =
        Timer.periodic(const Duration(milliseconds: 900), (_) => _sync());
  }

  static final PlayerController instance = PlayerController._();

  final AudioPlayer audio = AudioPlayer(useProxyForRequestHeaders: false);
  VideoPlayerController? video;

  VItem? current;
  PlayStreams? streams;
  VideoOption? selected;

  bool expanded = false;
  bool fullscreen = false;
  bool loading = false;
  bool videoLoading = false;
  String? error;

  bool loop = false;
  double speed = 1.0;
  DateTime? sleepAt;

  List<VItem> upNext = [];
  List<VItem> queue = [];
  final List<VItem> previous = [];
  RelatedPager? _related;

  // ignore: unused_field
  Timer? _syncTimer;
  Timer? _sleepTimer;
  bool _inBackground = false;
  bool _completing = false;
  bool _initingVideo = false;
  int _token = 0;

  LibraryStore get _lib => LibraryStore.instance;

  // ------------------------------------------------------------------
  // Loading
  // ------------------------------------------------------------------

  /// Play a list starting at [index]; the rest becomes the queue.
  Future<void> playList(List<VItem> items, int index) {
    return play(items[index], newQueue: items.sublist(index + 1));
  }

  Future<void> play(VItem item,
      {List<VItem>? newQueue, bool pushPrev = true, bool expand = true}) async {
    final token = ++_token;
    final cur = current;
    if (pushPrev && cur != null && cur.id != item.id) {
      previous.add(cur);
      if (previous.length > 50) previous.removeAt(0);
    }
    if (newQueue != null) queue = List.of(newQueue);
    queue.removeWhere((e) => e.id == item.id);

    current = item;
    if (expand) expanded = true;
    loading = true;
    error = null;
    streams = null;
    selected = null;
    upNext = [];
    _related = RelatedPager(item.id);
    await _disposeVideo();
    notifyListeners();
    _lib.addHistory(item);

    try {
      await audio.stop();
      final s = await YtService.streams(item.id);
      if (token != _token) return;
      streams = s;
      await audio.setAudioSource(AudioSource.uri(
        Uri.parse(s.audioUrl),
        headers: const {'User-Agent': kStreamUserAgent},
        tag: MediaItem(
          id: item.id,
          title: item.title,
          artist: item.author,
          album: 'ANGKOR PRIM',
          artUri: Uri.parse(item.thumb),
          duration: item.durationSec > 0 ? item.duration : null,
        ),
      ));
      if (token != _token) return;
      audio.play();
      loading = false;
      notifyListeners();

      if (s.videos.isNotEmpty) {
        selected = _pickOption(s.videos);
        if (!_inBackground && !_lib.audioOnly) {
          await _initVideo(token);
        }
      }
    } catch (e) {
      if (token != _token) return;
      loading = false;
      error = 'មិនអាចចាក់វីដេអូនេះបានទេ។ សូមព្យាយាមម្តងទៀត។\n$e';
      notifyListeners();
    }
    _loadRelated(token);
  }

  Future<void> retry() async {
    final c = current;
    if (c == null) return;
    YtService.reset();
    await play(c, pushPrev: false);
  }

  VideoOption _pickOption(List<VideoOption> list) {
    for (final o in list) {
      if (o.height <= _lib.maxHeight) return o;
    }
    return list.last;
  }

  Future<void> _initVideo(int token) async {
    final opt = selected;
    if (opt == null || _initingVideo) return;
    _initingVideo = true;
    videoLoading = true;
    notifyListeners();
    final c = VideoPlayerController.networkUrl(
      Uri.parse(opt.url),
      httpHeaders: const {'User-Agent': kStreamUserAgent},
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      if (token != _token || _inBackground || _lib.audioOnly) {
        await c.dispose();
      } else {
        await c.setVolume(0);
        await c.setPlaybackSpeed(speed);
        await c.seekTo(audio.position);
        video = c;
        if (audio.playing) await c.play();
      }
    } catch (_) {
      await c.dispose();
    }
    _initingVideo = false;
    videoLoading = false;
    notifyListeners();
  }

  Future<void> _disposeVideo() async {
    final v = video;
    video = null;
    if (v != null) {
      try {
        await v.pause();
      } catch (_) {}
      await v.dispose();
    }
  }

  Future<void> _loadRelated(int token) async {
    final pager = _related;
    if (pager == null) return;
    try {
      final r = await pager.load();
      if (token != _token) return;
      upNext = r.where((e) => e.id != current?.id).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadMoreRelated() async {
    final pager = _related;
    if (pager == null || !pager.hasMore) return;
    final token = _token;
    try {
      final r = await pager.load();
      if (token != _token) return;
      final ids = upNext.map((e) => e.id).toSet();
      upNext.addAll(r.where((e) => !ids.contains(e.id) && e.id != current?.id));
      notifyListeners();
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // Sync & state
  // ------------------------------------------------------------------

  void _onAudioState(PlayerState s) {
    final v = video;
    if (v != null && v.value.isInitialized) {
      final shouldPlay =
          s.playing && s.processingState == ProcessingState.ready;
      if (shouldPlay && !v.value.isPlaying) {
        v.seekTo(audio.position);
        v.play();
      } else if (!shouldPlay && v.value.isPlaying) {
        v.pause();
      }
    }
    if (s.processingState == ProcessingState.completed && !_completing) {
      _completing = true;
      next().whenComplete(() => _completing = false);
    }
  }

  void _sync() {
    final v = video;
    if (v == null || !v.value.isInitialized || _inBackground) return;
    if (!audio.playing || audio.processingState != ProcessingState.ready) {
      return;
    }
    final a = audio.position;
    final diff = (v.value.position - a).inMilliseconds.abs();
    if (diff > 600) {
      v.seekTo(a + const Duration(milliseconds: 200));
    }
    if (!v.value.isPlaying) v.play();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App in background or screen off: keep audio, release the picture.
      _inBackground = true;
      _disposeVideo();
    } else if (state == AppLifecycleState.resumed) {
      final wasBg = _inBackground;
      _inBackground = false;
      if (wasBg &&
          current != null &&
          selected != null &&
          video == null &&
          !_lib.audioOnly) {
        _initVideo(_token);
      }
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // Controls
  // ------------------------------------------------------------------

  void togglePlay() {
    if (audio.playing) {
      audio.pause();
    } else {
      if (audio.processingState == ProcessingState.completed) {
        audio.seek(Duration.zero);
      }
      audio.play();
    }
  }

  Future<void> seek(Duration d) async {
    await audio.seek(d);
    await video?.seekTo(d);
  }

  Future<void> seekRelative(int seconds) async {
    final dur = audio.duration ?? current?.duration ?? Duration.zero;
    var p = audio.position + Duration(seconds: seconds);
    if (p < Duration.zero) p = Duration.zero;
    if (dur > Duration.zero && p > dur) p = dur;
    await seek(p);
  }

  Future<void> next() async {
    if (queue.isNotEmpty) {
      await play(queue.removeAt(0), expand: false);
      return;
    }
    if (_lib.autoplay && upNext.isNotEmpty) {
      final recent = previous.map((e) => e.id).toSet();
      final pick = upNext.firstWhere((e) => !recent.contains(e.id),
          orElse: () => upNext.first);
      await play(pick, expand: false);
      return;
    }
    await audio.pause();
    await seek(Duration.zero);
  }

  Future<void> prev() async {
    if (audio.position > const Duration(seconds: 3) || previous.isEmpty) {
      await seek(Duration.zero);
      return;
    }
    final p = previous.removeLast();
    await play(p, pushPrev: false, expand: false);
  }

  Future<void> setQuality(VideoOption o) async {
    selected = o;
    _lib.setMaxHeight(o.height);
    await _disposeVideo();
    notifyListeners();
    if (!_lib.audioOnly) await _initVideo(_token);
  }

  Future<void> setAudioOnly(bool v) async {
    _lib.setAudioOnly(v);
    if (v) {
      await _disposeVideo();
      notifyListeners();
    } else if (selected != null) {
      await _initVideo(_token);
    }
  }

  Future<void> setSpeed(double s) async {
    speed = s;
    await audio.setSpeed(s);
    await video?.setPlaybackSpeed(s);
    notifyListeners();
  }

  Future<void> toggleLoop() async {
    loop = !loop;
    await audio.setLoopMode(loop ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  void setSleep(Duration? d) {
    _sleepTimer?.cancel();
    if (d == null) {
      sleepAt = null;
    } else {
      sleepAt = DateTime.now().add(d);
      _sleepTimer = Timer(d, () {
        audio.pause();
        sleepAt = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void addToQueue(VItem v) {
    if (current == null) {
      play(v);
      return;
    }
    queue.removeWhere((e) => e.id == v.id);
    queue.add(v);
    notifyListeners();
  }

  void playNextInQueue(VItem v) {
    if (current == null) {
      play(v);
      return;
    }
    queue.removeWhere((e) => e.id == v.id);
    queue.insert(0, v);
    notifyListeners();
  }

  void removeFromQueue(VItem v) {
    queue.removeWhere((e) => e.id == v.id);
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Panel state
  // ------------------------------------------------------------------

  void expand() {
    if (current == null) return;
    expanded = true;
    notifyListeners();
  }

  void minimize() {
    if (fullscreen) setFullscreen(false);
    if (!expanded) return;
    expanded = false;
    notifyListeners();
  }

  Future<void> close() async {
    _token++;
    if (fullscreen) setFullscreen(false);
    expanded = false;
    current = null;
    streams = null;
    selected = null;
    upNext = [];
    queue = [];
    await _disposeVideo();
    await audio.stop();
    notifyListeners();
  }

  void setFullscreen(bool v) {
    fullscreen = v;
    if (v) {
      final ar = video?.value.aspectRatio ?? 16 / 9;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(ar < 1
          ? [DeviceOrientation.portraitUp]
          : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    notifyListeners();
  }
}
