import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../player/player_controller.dart';
import '../screens/channel.dart';
import '../services/library_store.dart';
import '../services/yt_service.dart';

/// Navigation helper: every bottom tab has its own Navigator.
class AppNav {
  static final keys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  static int tab = 0;

  static void push(Widget page) {
    PlayerController.instance.minimize();
    keys[tab].currentState?.push(MaterialPageRoute(builder: (_) => page));
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
}

/// App logo: gold rounded play mark + wordmark.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size * 1.45,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kAccent, kAccentDeep]),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: size * 0.85),
      ),
      const SizedBox(width: 6),
      Text('ANGKOR PRIM',
          style: TextStyle(
              fontSize: size * 0.82,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Colors.white)),
    ]);
  }
}

class NetImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return Container(color: kSurface);
    return Image.network(
      url,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(color: kSurface),
      loadingBuilder: (c, child, p) =>
          p == null ? child : Container(color: kSurface),
    );
  }
}

class LetterAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  const LetterAvatar(this.name, {super.key, this.url, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final colors = [
      const Color(0xFF8E44AD),
      const Color(0xFF2980B9),
      const Color(0xFF16A085),
      const Color(0xFFD35400),
      const Color(0xFFC0392B),
      const Color(0xFF7F8C8D),
    ];
    final bg = colors[name.hashCode.abs() % colors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundImage: (url != null && url!.isNotEmpty) ? NetworkImage(url!) : null,
      child: Text(letter,
          style: TextStyle(color: Colors.white, fontSize: radius * 0.9)),
    );
  }
}

class DurationBadge extends StatelessWidget {
  final VItem v;
  const DurationBadge(this.v, {super.key});

  @override
  Widget build(BuildContext context) {
    if (!v.isLive && v.durationSec <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: v.isLive ? kAccentDeep : Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(v.isLive ? 'LIVE' : fmtDuration(v.duration),
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Big home-feed style card.
class VideoCard extends StatelessWidget {
  final VItem v;
  final VoidCallback? onTap;
  const VideoCard(this.v, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => PlayerController.instance.play(v),
      onLongPress: () => showVideoMenu(context, v),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            NetImage(v.thumb),
            Positioned(right: 8, bottom: 8, child: DurationBadge(v)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 0, 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => openChannel(v.channelId, v.author),
              child: LetterAvatar(v.author),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, height: 1.3)),
                const SizedBox(height: 4),
                Text(subtitleOf(v),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: Colors.white60)),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () => showVideoMenu(context, v),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Compact row (up next, library, search in music mode).
class VideoTile extends StatelessWidget {
  final VItem v;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool highlight;
  const VideoTile(this.v, {super.key, this.onTap, this.trailing, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => PlayerController.instance.play(v),
      onLongPress: () => showVideoMenu(context, v),
      child: Container(
        color: highlight ? Colors.white10 : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 160,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(v.thumbSmall),
                  Positioned(right: 4, bottom: 4, child: DurationBadge(v)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.3)),
              const SizedBox(height: 4),
              Text(v.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white60)),
              if (v.views > 0)
                Text('${fmtCount(v.views)} ដង',
                    style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ]),
          ),
          trailing ??
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.more_vert, size: 18),
                onPressed: () => showVideoMenu(context, v),
              ),
        ]),
      ),
    );
  }
}

void openChannel(String channelId, String name) {
  if (channelId.isEmpty) return;
  AppNav.push(ChannelScreen(channelId: channelId, name: name));
}

Future<void> showVideoMenu(BuildContext context, VItem v) {
  final lib = LibraryStore.instance;
  final p = PlayerController.instance;
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.playlist_play),
          title: const Text('ចាក់បន្ទាប់'),
          onTap: () {
            Navigator.pop(ctx);
            p.playNextInQueue(v);
            toast(context, 'នឹងចាក់បន្ទាប់');
          },
        ),
        ListTile(
          leading: const Icon(Icons.queue_music),
          title: const Text('បន្ថែមទៅជួរ'),
          onTap: () {
            Navigator.pop(ctx);
            p.addToQueue(v);
            toast(context, 'បានបន្ថែមទៅជួរ');
          },
        ),
        ListTile(
          leading: Icon(lib.isSaved(v.id) ? Icons.watch_later : Icons.watch_later_outlined),
          title: Text(lib.isSaved(v.id) ? 'ដកចេញពី មើលពេលក្រោយ' : 'រក្សាទុក មើលពេលក្រោយ'),
          onTap: () {
            Navigator.pop(ctx);
            lib.toggleSave(v);
          },
        ),
        ListTile(
          leading: Icon(lib.isLiked(v.id) ? Icons.thumb_up : Icons.thumb_up_outlined),
          title: Text(lib.isLiked(v.id) ? 'ដកការចូលចិត្ត' : 'ចូលចិត្ត'),
          onTap: () {
            Navigator.pop(ctx);
            lib.toggleLike(v);
          },
        ),
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text('ទៅកាន់ឆានែល ${v.author}'),
          onTap: () {
            Navigator.pop(ctx);
            openChannel(v.channelId, v.author);
          },
        ),
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('ចម្លងតំណ (Share)'),
          onTap: () {
            Navigator.pop(ctx);
            Clipboard.setData(ClipboardData(text: v.url));
            toast(context, 'បានចម្លងតំណ');
          },
        ),
      ]),
    ),
  );
}

/// Infinite-scroll list of videos from a [Pager].
class PagedVideoList extends StatefulWidget {
  final Pager Function() pagerBuilder;
  final bool compact;
  final Widget? header;
  final bool playAsList;

  const PagedVideoList({
    super.key,
    required this.pagerBuilder,
    this.compact = false,
    this.header,
    this.playAsList = false,
  });

  @override
  State<PagedVideoList> createState() => _PagedVideoListState();
}

class _PagedVideoListState extends State<PagedVideoList> {
  late Pager _pager;
  final List<VItem> _items = [];
  bool _loading = false;
  String? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _pager = widget.pagerBuilder();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 800) {
        _more();
      }
    });
    _more();
  }

  @override
  void didUpdateWidget(covariant PagedVideoList old) {
    super.didUpdateWidget(old);
    if (old.key != widget.key) _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _pager = widget.pagerBuilder();
      _items.clear();
      _error = null;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || !_pager.hasMore) return;
    setState(() => _loading = true);
    try {
      final r = await _pager.load();
      final ids = _items.map((e) => e.id).toSet();
      _items.addAll(r.where((e) => !ids.contains(e.id)));
      _error = null;
    } catch (e) {
      _error = 'មិនអាចផ្ទុកបានទេ។ ពិនិត្យអ៊ីនធឺណិត។';
      YtService.reset();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _tap(int i) {
    if (widget.playAsList) {
      PlayerController.instance.playList(_items, i);
    } else {
      PlayerController.instance.play(_items[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasHeader = widget.header != null;
    final count = _items.length + 1 + (hasHeader ? 1 : 0);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (c, i) {
          if (hasHeader) {
            if (i == 0) return widget.header!;
            i -= 1;
          }
          if (i < _items.length) {
            final v = _items[i];
            return widget.compact
                ? VideoTile(v, onTap: () => _tap(i))
                : VideoCard(v, onTap: () => _tap(i));
          }
          if (_error != null && _items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                const Icon(Icons.wifi_off, size: 48, color: Colors.white38),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _refresh, child: const Text('ព្យាយាមម្តងទៀត')),
              ]),
            );
          }
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('មិនមានលទ្ធផល')),
            );
          }
          return const SizedBox(height: 80);
        },
      ),
    );
  }
}
