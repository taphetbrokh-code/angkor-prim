// ignore_for_file: deprecated_member_use
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as y;

import '../models.dart';
import 'stream_proxy.dart';

/// User-Agent that matches the default client used to resolve streams.
const kStreamUserAgent =
    'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';

/// Thin wrapper around youtube_explode_dart that converts everything to
/// the app's own models.
class YtService {
  YtService._();

  static y.YoutubeExplode _yt = y.YoutubeExplode();
  static final Map<String, y.Video> _videoCache = {};

  /// Recreate the client (useful after network errors).
  static void reset() {
    try {
      _yt.close();
    } catch (_) {}
    _yt = y.YoutubeExplode();
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
  static Future<PlayStreams> streams(String id) async {
    final m = await _yt.videos.streamsClient.getManifest(id);

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
    final mp4Audio =
        m.audioOnly.where((s) => s.container == y.StreamContainer.mp4).toList();
    if (mp4Audio.isNotEmpty) {
      audioUrl = await local(mp4Audio.withHighestBitrate(), 'audio');
    } else if (m.audioOnly.isNotEmpty) {
      audioUrl = await local(m.audioOnly.withHighestBitrate(), 'audio');
    }

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

    if (audioUrl == null) {
      throw Exception('រកមិនឃើញ stream សម្រាប់វីដេអូនេះទេ');
    }
    final videos = byHeight.values.toList()
      ..sort((a, b) => b.height.compareTo(a.height));
    return PlayStreams(audioUrl: audioUrl, videos: videos);
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
