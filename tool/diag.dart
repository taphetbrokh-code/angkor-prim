// Diagnostic: which YouTube clients give streams that can actually be
// downloaded, and how fast. Run with: dart run tool/diag.dart
import 'dart:async';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final out = StringBuffer();
void log(Object o) {
  print(o);
  out.writeln(o);
}

Future<void> main() async {
  final yt = YoutubeExplode();
  final ids = <String>[];
  try {
    final s = await yt.search.search('ចម្រៀងខ្មែរ ថ្មី');
    ids.addAll(s.take(2).map((v) => v.id.value));
    log('search ok: ${s.length} results');
  } catch (e) {
    log('search FAILED: $e');
  }
  ids.add('dQw4w9WgXcQ');

  final clients = <String, YoutubeApiClient?>{
    'default': null,
    'androidSdkless': YoutubeApiClient.androidSdkless,
    'androidVr': YoutubeApiClient.androidVr,
    'ios': YoutubeApiClient.ios,
    'tv': YoutubeApiClient.tv,
    'mweb': YoutubeApiClient.mweb,
    'android': YoutubeApiClient.android,
  };

  for (final id in ids.take(2)) {
    log('\n===== video $id =====');
    for (final e in clients.entries) {
      final sw = Stopwatch()..start();
      try {
        final m = await yt.videos.streamsClient
            .getManifest(id, ytClients: e.value == null ? null : [e.value!])
            .timeout(const Duration(seconds: 40));
        final t1 = sw.elapsedMilliseconds;
        final audio = m.audioOnly.isEmpty ? null : m.audioOnly.withHighestBitrate();
        log('[${e.key}] manifest ${t1}ms: audio=${m.audioOnly.length} video=${m.videoOnly.length} muxed=${m.muxed.length} hls=${m.hls.length}');
        if (audio == null) continue;
        log('   audio itag=${audio.tag} ${audio.container.name} size=${audio.size.totalBytes} frags=${audio.fragments.length} throttled=${audio.isThrottled} c=${audio.url.queryParameters['c']}');

        // 1) library downloader
        sw.reset();
        var got = 0;
        try {
          await for (final chunk in yt.videos.streamsClient.get(audio).timeout(const Duration(seconds: 20))) {
            got += chunk.length;
            if (got >= 1024 * 1024) break;
          }
          log('   lib-get: $got bytes in ${sw.elapsedMilliseconds}ms');
        } catch (err) {
          log('   lib-get FAILED after $got bytes: $err');
        }

        // 2) plain HTTP GET with range param / header
        for (final mode in ['param', 'header', 'none']) {
          sw.reset();
          try {
            final client = HttpClient();
            var url = audio.url;
            if (mode == 'param') {
              url = url.replace(queryParameters: {...url.queryParameters, 'range': '0-1048575'});
            }
            final req = await client.getUrl(url);
            YoutubeHttpClient.defaultHeaders.forEach(req.headers.set);
            if (mode == 'header') req.headers.set('range', 'bytes=0-1048575');
            final res = await req.close().timeout(const Duration(seconds: 20));
            var n = 0;
            await for (final c in res.timeout(const Duration(seconds: 20))) {
              n += c.length;
              if (n >= 1048576) break;
            }
            log('   http-$mode: status=${res.statusCode} $n bytes in ${sw.elapsedMilliseconds}ms');
            client.close(force: true);
          } catch (err) {
            log('   http-$mode FAILED: $err');
          }
        }
      } catch (err) {
        log('[${e.key}] FAILED after ${sw.elapsedMilliseconds}ms: $err');
      }
    }
  }
  yt.close();
  File('diag-result.txt').writeAsStringSync(out.toString());
  exit(0);
}
