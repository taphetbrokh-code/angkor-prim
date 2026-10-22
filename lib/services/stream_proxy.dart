import 'dart:async';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart' as y;

/// A tiny local HTTP server that the players (just_audio / video_player)
/// read from. It forwards each request to googlevideo the same way
/// youtube_explode downloads streams (same headers, ranges split into
/// ~10 MB pieces). Playing the googlevideo URL directly from ExoPlayer is
/// what caused "Source error" and very slow/throttled loading.
class StreamProxy {
  StreamProxy._();
  static final StreamProxy instance = StreamProxy._();

  static const _chunk = 10 * 1024 * 1024;

  HttpServer? _server;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 30);

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle, onError: (_) {});
  }

  /// Returns a local URL that streams [remote] (total size [length] bytes).
  Future<String> wrap(Uri remote, int length, String mime) async {
    await start();
    final port = _server!.port;
    return Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: port,
      path: '/s',
      queryParameters: {'u': remote.toString(), 'l': '$length', 'm': mime},
    ).toString();
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final q = req.uri.queryParameters;
      final remote = Uri.parse(q['u']!);
      final total = int.parse(q['l']!);
      final mime = q['m'] ?? 'application/octet-stream';

      var start = 0;
      var end = total - 1;
      final range = req.headers.value(HttpHeaders.rangeHeader);
      final partial = range != null && range.startsWith('bytes=');
      if (partial) {
        final parts = range.substring(6).split('-');
        start = int.tryParse(parts[0]) ?? 0;
        if (parts.length > 1 && parts[1].isNotEmpty) {
          end = int.tryParse(parts[1]) ?? end;
        }
      }
      if (end >= total) end = total - 1;
      if (start > end) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
        await res.close();
        return;
      }

      res.statusCode = partial ? HttpStatus.partialContent : HttpStatus.ok;
      res.headers.set(HttpHeaders.contentTypeHeader, mime);
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      res.headers.contentLength = end - start + 1;
      if (partial) {
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$total');
      }
      if (req.method == 'HEAD') {
        await res.close();
        return;
      }

      var pos = start;
      while (pos <= end) {
        final to = (pos + _chunk - 1) > end ? end : pos + _chunk - 1;
        await _pipeRange(remote, pos, to, res);
        pos = to + 1;
      }
      await res.close();
    } catch (_) {
      try {
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> _pipeRange(Uri remote, int from, int to, HttpResponse out) async {
    final android = remote.queryParameters['c'] == 'ANDROID';
    final url = android
        ? remote
        : remote.replace(queryParameters: {
            ...remote.queryParameters,
            'range': '$from-$to',
          });
    final up = await _client.getUrl(url);
    y.YoutubeHttpClient.defaultHeaders.forEach(up.headers.set);
    if (android) up.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-$to');
    final resp = await up.close();
    if (resp.statusCode >= 400) {
      await resp.drain<void>();
      throw HttpException('upstream ${resp.statusCode}');
    }
    await out.addStream(resp);
  }
}
