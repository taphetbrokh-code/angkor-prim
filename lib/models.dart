/// Plain data models used across the app (kept independent of the
/// YouTube library so they can be saved to local storage).
class VItem {
  final String id;
  final String title;
  final String author;
  final String channelId;
  final int durationSec;
  final int views;
  final String uploaded;
  final int? dateMs;
  final bool isLive;

  const VItem({
    required this.id,
    required this.title,
    required this.author,
    required this.channelId,
    this.durationSec = 0,
    this.views = 0,
    this.uploaded = '',
    this.dateMs,
    this.isLive = false,
  });

  String get thumb => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
  String get thumbSmall => 'https://i.ytimg.com/vi/$id/mqdefault.jpg';
  String get url => 'https://www.youtube.com/watch?v=$id';
  Duration get duration => Duration(seconds: durationSec);

  Map<String, dynamic> toJson() => {
        'id': id,
        't': title,
        'a': author,
        'c': channelId,
        'd': durationSec,
        'v': views,
        'u': uploaded,
        'dm': dateMs,
        'l': isLive,
      };

  factory VItem.fromJson(Map<String, dynamic> j) => VItem(
        id: j['id'] as String,
        title: (j['t'] ?? '') as String,
        author: (j['a'] ?? '') as String,
        channelId: (j['c'] ?? '') as String,
        durationSec: (j['d'] ?? 0) as int,
        views: (j['v'] ?? 0) as int,
        uploaded: (j['u'] ?? '') as String,
        dateMs: j['dm'] as int?,
        isLive: (j['l'] ?? false) as bool,
      );

  @override
  bool operator ==(Object other) => other is VItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class ChannelRef {
  final String id;
  final String name;
  final String logo;

  const ChannelRef({required this.id, required this.name, this.logo = ''});

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'l': logo};

  factory ChannelRef.fromJson(Map<String, dynamic> j) => ChannelRef(
        id: j['id'] as String,
        name: (j['n'] ?? '') as String,
        logo: (j['l'] ?? '') as String,
      );
}

class ChannelInfo {
  final String id;
  final String title;
  final String logoUrl;
  final String bannerUrl;
  final int? subscribers;

  const ChannelInfo({
    required this.id,
    required this.title,
    required this.logoUrl,
    required this.bannerUrl,
    this.subscribers,
  });
}

class VideoDetails {
  final String description;
  final int? likes;
  final int views;
  final DateTime? date;

  const VideoDetails({
    required this.description,
    this.likes,
    required this.views,
    this.date,
  });
}

class CommentItem {
  final String author;
  final String text;
  final int likes;
  final String time;
  final int replies;

  const CommentItem({
    required this.author,
    required this.text,
    required this.likes,
    required this.time,
    required this.replies,
  });
}

class VideoOption {
  final String label;
  final int height;
  final String url;
  final bool hls;

  const VideoOption(
      {required this.label, required this.height, required this.url, this.hls = false});
}

class PlayStreams {
  final String audioUrl;
  final bool audioHls;
  final List<VideoOption> videos;

  const PlayStreams({required this.audioUrl, required this.videos, this.audioHls = false});
}

// ---------- formatting helpers ----------

String fmtCount(int n) {
  if (n >= 1000000000) return '${_trim(n / 1000000000)}B';
  if (n >= 1000000) return '${_trim(n / 1000000)}M';
  if (n >= 1000) return '${_trim(n / 1000)}K';
  return '$n';
}

String _trim(double v) {
  final s = v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

String fmtAgo(DateTime? d, String fallback) {
  if (d == null) return fallback;
  final diff = DateTime.now().difference(d);
  if (diff.inDays >= 365) return '${diff.inDays ~/ 365} ឆ្នាំមុន';
  if (diff.inDays >= 30) return '${diff.inDays ~/ 30} ខែមុន';
  if (diff.inDays >= 7) return '${diff.inDays ~/ 7} សប្តាហ៍មុន';
  if (diff.inDays >= 1) return '${diff.inDays} ថ្ងៃមុន';
  if (diff.inHours >= 1) return '${diff.inHours} ម៉ោងមុន';
  return '${diff.inMinutes} នាទីមុន';
}

String subtitleOf(VItem v) {
  final parts = <String>[v.author];
  if (v.isLive) {
    parts.add('ផ្សាយផ្ទាល់');
  } else {
    if (v.views > 0) parts.add('${fmtCount(v.views)} ដង');
    final ago = fmtAgo(v.dateMs == null ? null : DateTime.fromMillisecondsSinceEpoch(v.dateMs!), v.uploaded);
    if (ago.isNotEmpty) parts.add(ago);
  }
  return parts.join(' · ');
}

double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
