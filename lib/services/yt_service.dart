// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as y;

import '../models.dart';
import 'stream_proxy.dart';
import 'webview_solver.dart';

/// User-Agent that matches the default client used to resolve streams.
const kStreamUserAgent =
    'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';

/// Thin wrapper around youtube_explode_dart that converts everything to
/// the app's own models.
class YtService {
  YtService._();

  static final WebViewEJSSolver _solver = WebViewEJSSolver();
  static y.YoutubeExplode _yt = y.YoutubeExplode(jsSolver: _solver);
  static final Map<String, y.Video> _videoCache = {};

  /// Recreate the client (useful after network errors).
  static void reset() {
    try {
      _yt.close();
    } catch (_) {}
    _yt = y.YoutubeExplode(jsSolver: _solver);
  }

  static VItem fromVideo(y.Video v) => VItem(
        id: v.id.value,
        title: v.title,
        author: v.author,
        channelId: v.channelId.value,
        durationSec: v.duration?.inSeconds ?? 0,
        views: v.engagement.viewCount,
        uploaded: v.uploadDateRaw ?? '',
        dateMs: (v.uploadDate ?? v.publishDate)?.millisecondsSinceEpoch,
        isLive: v.isLive,
      );

  // ---------------- search ----------------

  static Future<List<String>> suggestions(String q) async {
    if (q.trim().isEmpty) return [];
    try {
      return await _yt.search.getQuerySuggestions(q);
    } catch (_) {
      return [];
    }
  }

  // ---------------- video ----------------

  static Future<y.Video> _video(String id) async {
    final cached = _videoCache[id];
    if (cached != null) return cached;
    final v = await _yt.videos.get(id);
    _videoCache[id] = v;
    if (_videoCache.length > 50) _videoCache.remove(_videoCache.keys.first);
    return v;
  }

  static Future<VideoDetails> details(String id) async {
    final v = await _video(id);
    return VideoDetails(
      description: v.description,
      likes: v.engagement.likeCount,
      views: v.engagement.viewCount,
      date: v.uploadDate ?? v.publishDate,
    );
  }

  /// Resolve playable stream URLs: one audio stream (master) and a list of
  /// video-only qualities (shown muted, synced to the audio).
  // Clients to try, in order. The first one whose audio can really be
  // downloaded wins and is remembered, so the next video starts faster.
  static final List<(String, List<y.YoutubeApiClient>?)> _clients = [
    ('tv', [y.YoutubeApiClient.tv]),
    ('web', [y.YoutubeApiClient.safari]),
    ('androidVr', [y.YoutubeApiClient.androidVr]),
    ('ios', [y.YoutubeApiClient.ios]),
    ('android', [y.YoutubeApiClient.androidSdkless]),
    ('mweb', [y.YoutubeApiClient.mweb]),
  ];
  static int _goodClient = 0;

  static y.AudioOnlyStreamInfo? _bestAudio(y.StreamManifest m) {
    if (m.audioOnly.isEmpty) return null;
    final mp4 =
        m.audioOnly.where((s) => s.container == y.StreamContainer.mp4).toList();
    return mp4.isNotEmpty ? mp4.withHighestBitrate() : m.audioOnly.withHighestBitrate();
  }

  /// What the player is doing right now (shown under the spinner).
  static final ValueNotifier<String> status = ValueNotifier('');

  /// Find a manifest whose streams YouTube actually lets us download.
  /// All clients are tried at the same time; the first one that works wins.
  static Future<y.StreamManifest> _workingManifest(String id) {
    final errors = <String>[];
    final done = Completer<y.StreamManifest>();
    var pending = _clients.length;
    status.value = 'កំពុងភ្ជាប់ YouTube (${_clients.length} វិធី)...';

    Future<void> tryClient(int i) async {
      final (name, clients) = _clients[i];
      try {
        final m = await _yt.videos.streamsClient
            .getManifest(id, ytClients: clients)
            .timeout(const Duration(seconds: 25));
        if (done.isCompleted) return;
        final audio = _bestAudio(m);
        final y.StreamInfo? probe = audio ??
            (m.muxed.isNotEmpty ? m.muxed.withHighestBitrate() : null) ??
            (m.hls.isNotEmpty ? m.hls.first : null);
        if (probe == null) throw Exception('no streams');
        // probe: can we really download the first bytes?
        await _yt.videos.streamsClient
            .get(probe)
            .first
            .timeout(const Duration(seconds: 12));
        if (!done.isCompleted) {
          _goodClient = i;
          status.value = 'ប្រើ $name';
          done.complete(m);
        }
      } catch (e) {
        final msg = '$e'.split('\n').first;
        errors.add('$name: ${msg.length > 140 ? msg.substring(0, 140) : msg}');
        if (!done.isCompleted) {
          status.value = 'បរាជ័យ ${errors.length}/${_clients.length} វិធី...';
        }
      } finally {
        pending--;
        if (pending == 0 && !done.isCompleted) {
          done.completeError(Exception(errors.join('\n')));
        }
      }
    }

    // The client that worked last time gets a small head start.
    tryClient(_goodClient);
    for (var i = 0; i < _clients.length; i++) {
      if (i != _goodClient) tryClient(i);
    }
    return done.future;
  }

  static Future<PlayStreams> streams(String id) async {
    final m = await _workingManifest(id);

    // ---- audio ----
    final proxy = StreamProxy.instance;
    await proxy.reset();
    Future<String> local(y.StreamInfo s, String kind) => proxy.wrap(
          key: '${id}_${s.tag}',
          open: () => _yt.videos.streamsClient.get(s),
          length: s.size.totalBytes,
          mime:
              '$kind/${s.container == y.StreamContainer.mp4 ? 'mp4' : s.container.name}',
        );

    String? audioUrl;
    final bestAudio = _bestAudio(m);
    if (bestAudio != null) audioUrl = await local(bestAudio, 'audio');

    // ---- video ----
    final byHeight = <int, VideoOption>{};
    final h264 = m.videoOnly
        .where((s) =>
            s.container == y.StreamContainer.mp4 &&
            s.videoCodec.toLowerCase().startsWith('avc'))
        .toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
    for (final s in h264) {
      final h = s.videoResolution.height;
      if (h <= 0 || h > 1080) continue;
      if (byHeight.containsKey(h)) continue;
      byHeight[h] = VideoOption(label: '${h}p', height: h, url: await local(s, 'video'));
    }
    if (m.muxed.isNotEmpty) {
      final mux = m.muxed.withHighestBitrate();
      final h = mux.videoResolution.height;
      final muxUrl = await local(mux, 'video');
      byHeight.putIfAbsent(
          h, () => VideoOption(label: '${h}p', height: h, url: muxUrl));
      audioUrl ??= muxUrl;
    }

    // HLS (m3u8) streams from the web client: played directly by ExoPlayer.
    var audioHls = false;
    if (audioUrl == null && m.hls.isNotEmpty) {
      final hlsAudio = m.hls.whereType<y.HlsAudioStreamInfo>().toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
      final hlsMuxed = m.hls.whereType<y.HlsMuxedStreamInfo>().toList()
        ..sort((a, b) => a.bitrate.compareTo(b.bitrate));
      if (hlsAudio.isNotEmpty) {
        audioUrl = hlsAudio.first.url.toString();
        audioHls = true;
      } else if (hlsMuxed.isNotEmpty) {
        audioUrl = hlsMuxed.first.url.toString();
        audioHls = true;
      }
      for (final s in hlsMuxed) {
        final h = s.videoResolution.height;
        if (h <= 0 || h > 1080) continue;
        byHeight[h] = VideoOption(
            label: '${h}p', height: h, url: s.url.toString(), hls: true);
      }
    }

    if (audioUrl == null) {
      throw Exception('រកមិនឃើញ stream សម្រាប់វីដេអូនេះទេ');
    }
    final videos = byHeight.values.toList()
      ..sort((a, b) => b.height.compareTo(a.height));
    return PlayStreams(audioUrl: audioUrl, videos: videos, audioHls: audioHls);
  }

  // ---------------- channel ----------------

  static Future<ChannelInfo> channel(String id) async {
    final c = await _yt.channels.get(id);
    return ChannelInfo(
      id: c.id.value,
      title: c.title,
      logoUrl: c.logoUrl,
      bannerUrl: c.bannerUrl,
      subscribers: c.subscribersCount,
    );
  }

  // ---------------- comments ----------------

  static Future<List<CommentItem>> comments(String id) async {
    final v = await _video(id);
    final list = await _yt.videos.commentsClient.getComments(v);
    if (list == null) return [];
    return list
        .map((c) => CommentItem(
              author: c.author,
              text: c.text,
              likes: c.likeCount,
              time: c.publishedTime,
              replies: c.replyCount,
            ))
        .toList();
  }

  static Future<y.Video> videoRaw(String id) => _video(id);
  static y.YoutubeExplode get client => _yt;
}

/// A paged list of videos (search results, related videos, uploads...).
abstract class Pager {
  bool hasMore = true;
  bool _busy = false;

  Future<List<VItem>> _first();
  Future<List<VItem>> _next();

  bool _started = false;

  /// Returns the next batch (first call returns the first page).
  Future<List<VItem>> load() async {
    if (_busy || !hasMore) return [];
    _busy = true;
    try {
      final r = _started ? await _next() : await _first();
      _started = true;
      if (r.isEmpty) hasMore = false;
      return r;
    } finally {
      _busy = false;
    }
  }
}

class SearchPager extends Pager {
  final String query;
  y.VideoSearchList? _list;
  SearchPager(this.query);

  @override
  Future<List<VItem>> _first() async {
    _list = await YtService.client.search.search(query);
    return _list!.map(YtService.fromVideo).toList();
  }

  @override
  Future<List<VItem>> _next() async {
    final n = await _list?.nextPage();
    if (n == null) {
      hasMore = false;
      return [];
    }
    _list = n;
    return n.map(YtService.fromVideo).toList();
  }
}

class RelatedPager extends Pager {
  final String videoId;
  y.RelatedVideosList? _list;
  RelatedPager(this.videoId);

  @override
  Future<List<VItem>> _first() async {
    final v = await YtService.videoRaw(videoId);
    _list = await YtService.client.videos.getRelatedVideos(v);
    if (_list == null) {
      hasMore = false;
      return [];
    }
    return _list!.map(YtService.fromVideo).toList();
  }

  @override
  Future<List<VItem>> _next() async {
    final n = await _list?.nextPage();
    if (n == null) {
      hasMore = false;
      return [];
    }
    _list = n;
    return n.map(YtService.fromVideo).toList();
  }
}

class UploadsPager extends Pager {
  final String channelId;
  y.ChannelUploadsList? _list;
  UploadsPager(this.channelId);

  @override
  Future<List<VItem>> _first() async {
    _list = await YtService.client.channels.getUploadsFromPage(channelId);
    return _list!.map(YtService.fromVideo).toList();
  }

  @override
  Future<List<VItem>> _next() async {
    final n = await _list?.nextPage();
    if (n == null) {
      hasMore = false;
      return [];
    }
    _list = n;
    return n.map(YtService.fromVideo).toList();
  }
}
