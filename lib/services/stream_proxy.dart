import 'dart:async';
import 'dart:io';

/// Local HTTP server the players (just_audio / video_player) read from.
///
/// Each stream is downloaded with youtube_explode's own downloader (which
/// knows how to fetch every kind of YouTube stream: normal, throttled and
/// fragmented DASH) into a temp file. The player is served from that file
/// while it is still downloading, so playback starts as soon as the first
/// bytes arrive. Playing googlevideo URLs directly from ExoPlayer gave
/// "(0) Source error".
class StreamProxy {
  StreamProxy._();
  static final StreamProxy instance = StreamProxy._();

  HttpServer? _server;
  final Map<String, _Download> _downloads = {};
  String? lastError;

  Future<void> _start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle, onError: (_) {});
  }

  /// Cancel and delete all downloads (call when a new video starts).
  Future<void> reset() async {
    final all = _downloads.values.toList();
    _downloads.clear();
    lastError = null;
    for (final d in all) {
      await d.dispose();
    }
  }

  /// Register a stream and return the local URL that plays it.
  /// The download only starts when the player first asks for it.
  Future<String> wrap({
    required String key,
    required Stream<List<int>> Function() open,
    required int length,
    required String mime,
  }) async {
    await _start();
    _downloads.putIfAbsent(key, () => _Download(key, open, length, mime));
    return 'http://127.0.0.1:${_server!.port}/s/${Uri.encodeComponent(key)}';
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final key = Uri.decodeComponent(req.uri.pathSegments.last);
      final d = _downloads[key];
      if (d == null) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      d.ensureStarted(onError: (e) => lastError = '$e');
      await d.serve(req);
    } catch (e) {
      lastError = '$e';
      try {
        await res.close();
      } catch (_) {}
    }
  }
}

class _Download {
  final String key;
  final Stream<List<int>> Function() open;
  final int declaredLength;
  final String mime;

  _Download(this.key, this.open, this.declaredLength, this.mime);

  File? _file;
  RandomAccessFile? _out;
  StreamSubscription<List<int>>? _sub;
  int have = 0;
  bool done = false;
  Object? error;
  bool _disposed = false;
  final List<Completer<void>> _waiters = [];

  int get total => declaredLength > 0 ? declaredLength : (done ? have : -1);

  void ensureStarted({required void Function(Object) onError}) {
    if (_file != null) return;
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    _file = File('${Directory.systemTemp.path}/ap_$safe.bin');
    try {
      if (_file!.existsSync()) _file!.deleteSync();
    } catch (_) {}
    _out = _file!.openSync(mode: FileMode.write);
    late final StreamSubscription<List<int>> sub;
    sub = open().listen(
      (data) {
        // write sequentially; pause the download while each piece is written
        sub.pause();
        _out!.writeFrom(data).then((_) {
          have += data.length;
          _wake();
          sub.resume();
        }, onError: (Object e) {
          error = e;
          onError(e);
          done = true;
          _wake();
          sub.cancel();
        });
      },
      onError: (Object e) {
        error = e;
        onError(e);
        done = true;
        _wake();
      },
      onDone: () {
        done = true;
        _wake();
      },
      cancelOnError: true,
    );
    _sub = sub;
  }

  void _wake() {
    final w = List.of(_waiters);
    _waiters.clear();
    for (final c in w) {
      if (!c.isCompleted) c.complete();
    }
  }

  /// Wait until byte [pos] is downloaded (or the download finished).
  Future<void> _waitFor(int pos) async {
    while (!_disposed && !done && have <= pos) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future.timeout(const Duration(seconds: 30), onTimeout: () {});
    }
  }

  Future<void> serve(HttpRequest req) async {
    final res = req.response;
    var start = 0;
    int? end;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    final partial = range != null && range.startsWith('bytes=') && total > 0;
    if (partial) {
      final parts = range.substring(6).split('-');
      start = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1 && parts[1].isNotEmpty) end = int.tryParse(parts[1]);
    }

    res.headers.set(HttpHeaders.contentTypeHeader, mime);
    final len = total;
    if (len > 0) {
      end = (end == null || end >= len) ? len - 1 : end;
      if (start > end) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$len');
        await res.close();
        return;
      }
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      res.headers.contentLength = end - start + 1;
      if (partial) {
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$len');
      }
    }
    if (req.method == 'HEAD') {
      await res.close();
      return;
    }

    // First wait for data so a failure can still be reported as an error code.
    await _waitFor(start);
    if (have <= start && error != null) {
      res.statusCode = HttpStatus.badGateway;
      res.headers.contentLength = 0;
      await res.close();
      return;
    }

    final raf = await _file!.open();
    try {
      var pos = start;
      while (!_disposed) {
        if (end != null && pos > end) break;
        await _waitFor(pos);
        if (have <= pos) break; // finished (or failed) and nothing more
        final last = end == null ? have - 1 : (have - 1 < end ? have - 1 : end);
        final count = last - pos + 1;
        await raf.setPosition(pos);
        final bytes = await raf.read(count > 512 * 1024 ? 512 * 1024 : count);
        if (bytes.isEmpty) break;
        res.add(bytes);
        await res.flush();
        pos += bytes.length;
      }
    } finally {
      await raf.close();
      await res.close();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _wake();
    try {
      await _sub?.cancel();
    } catch (_) {}
    try {
      await _out?.close();
    } catch (_) {}
    try {
      if (_file != null && _file!.existsSync()) _file!.deleteSync();
    } catch (_) {}
  }
}
