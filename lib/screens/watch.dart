import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../player/player_controller.dart';
import '../services/library_store.dart';
import '../services/yt_service.dart';
import '../widgets/common.dart';
import '../widgets/player_view.dart';

class WatchScreen extends StatelessWidget {
  const WatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = PlayerController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([p, LibraryStore.instance]),
      builder: (context, _) {
        final v = p.current;
        if (v == null) return const SizedBox.shrink();
        if (p.fullscreen) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: PlayerView(fullscreen: true),
          );
        }
        return Scaffold(
          body: Column(children: [
            Container(color: Colors.black, height: MediaQuery.of(context).padding.top),
            GestureDetector(
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 250) p.minimize();
                if ((d.primaryVelocity ?? 0) < -250) p.setFullscreen(true);
              },
              child: const PlayerView(),
            ),
            Expanded(child: _WatchBody(key: ValueKey(v.id), v: v)),
          ]),
        );
      },
    );
  }
}

class _WatchBody extends StatefulWidget {
  final VItem v;
  const _WatchBody({super.key, required this.v});

  @override
  State<_WatchBody> createState() => _WatchBodyState();
}

class _WatchBodyState extends State<_WatchBody> {
  VideoDetails? _details;
  ChannelInfo? _channel;
  bool _descOpen = false;

  @override
  void initState() {
    super.initState();
    YtService.details(widget.v.id).then((d) {
      if (mounted) setState(() => _details = d);
    }).catchError((_) {});
    if (widget.v.channelId.isNotEmpty) {
      YtService.channel(widget.v.channelId).then((c) {
        if (mounted) setState(() => _channel = c);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerController.instance;
    final lib = LibraryStore.instance;
    final v = widget.v;
    final d = _details;
    final views = d?.views ?? v.views;
    final dateText = fmtAgo(d?.date, v.uploaded);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) p.loadMoreRelated();
        return false;
      },
      child: ListView(padding: EdgeInsets.zero, children: [
        // ---- title ----
        InkWell(
          onTap: () => setState(() => _descOpen = !_descOpen),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.title,
                  maxLines: _descOpen ? 6 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 6),
              Text(
                [
                  if (views > 0) '${fmtCount(views)} ដង',
                  if (dateText.isNotEmpty) dateText,
                  '...ច្រើនទៀត',
                ].join('  '),
                style: const TextStyle(fontSize: 12.5, color: Colors.white60),
              ),
            ]),
          ),
        ),
        // ---- channel row ----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            GestureDetector(
              onTap: () => openChannel(v.channelId, v.author),
              child: LetterAvatar(v.author, url: _channel?.logoUrl),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => openChannel(v.channelId, v.author),
                child: Row(children: [
                  Flexible(
                    child: Text(v.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (_channel?.subscribers != null) ...[
                    const SizedBox(width: 6),
                    Text(fmtCount(_channel!.subscribers!),
                        style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  ],
                ]),
              ),
            ),
            _SubButton(v: v, logo: _channel?.logoUrl ?? ''),
          ]),
        ),
        // ---- actions ----
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _ActionChip(
                icon: lib.isLiked(v.id) ? Icons.thumb_up : Icons.thumb_up_outlined,
                label: d?.likes != null ? fmtCount(d!.likes! + (lib.isLiked(v.id) ? 1 : 0)) : 'ចូលចិត្ត',
                onTap: () => lib.toggleLike(v),
              ),
              _ActionChip(
                icon: Icons.share_outlined,
                label: 'ចែករំលែក',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: v.url));
                  toast(context, 'បានចម្លងតំណ');
                },
              ),
              _ActionChip(
                icon: lib.audioOnly ? Icons.headphones : Icons.headphones_outlined,
                label: 'សំឡេងតែប៉ុណ្ណោះ',
                active: lib.audioOnly,
                onTap: () => p.setAudioOnly(!lib.audioOnly),
              ),
              _ActionChip(
                icon: Icons.repeat_one,
                label: 'Loop',
                active: p.loop,
                onTap: p.toggleLoop,
              ),
              _ActionChip(
                icon: lib.isSaved(v.id) ? Icons.watch_later : Icons.watch_later_outlined,
                label: 'រក្សាទុក',
                onTap: () => lib.toggleSave(v),
              ),
              _ActionChip(
                icon: Icons.bedtime_outlined,
                label: p.sleepAt == null ? 'Sleep' : 'Sleep ✓',
                active: p.sleepAt != null,
                onTap: () => showPlayerSettings(context),
              ),
            ],
          ),
        ),
        // ---- description ----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Material(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _descOpen = !_descOpen),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: d == null
                    ? const Text('កំពុងផ្ទុក...', style: TextStyle(color: Colors.white54))
                    : SelectableText.rich(
                        TextSpan(text: d.description.isEmpty ? 'គ្មានការពិពណ៌នា' : d.description),
                        maxLines: _descOpen ? null : 3,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                        onTap: () => setState(() => _descOpen = !_descOpen),
                      ),
              ),
            ),
          ),
        ),
        // ---- comments ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Material(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('មតិយោបល់', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.unfold_more),
              onTap: () => _showComments(context, v),
            ),
          ),
        ),
        // ---- queue ----
        if (p.queue.isNotEmpty) ...[
          _Header('ជួរចាក់ (${p.queue.length})'),
          for (final q in p.queue)
            VideoTile(
              q,
              onTap: () => p.play(q),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => p.removeFromQueue(q),
              ),
            ),
        ],
        // ---- up next ----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Row(children: [
            const Expanded(
              child: Text('បន្ទាប់', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Text('Autoplay', style: TextStyle(fontSize: 12, color: Colors.white60)),
            Switch(value: lib.autoplay, onChanged: lib.setAutoplay),
          ]),
        ),
        if (p.upNext.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        for (final r in p.upNext) VideoTile(r, onTap: () => p.play(r)),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      );
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _ActionChip({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: active ? kAccent.withValues(alpha: 0.25) : Colors.white12,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Icon(icon, size: 18, color: active ? kAccent : null),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SubButton extends StatelessWidget {
  final VItem v;
  final String logo;
  const _SubButton({required this.v, required this.logo});

  @override
  Widget build(BuildContext context) {
    final lib = LibraryStore.instance;
    final sub = lib.isSub(v.channelId);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: sub ? Colors.white12 : Colors.white,
        foregroundColor: sub ? Colors.white : Colors.black,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: v.channelId.isEmpty
          ? null
          : () => lib.toggleSub(ChannelRef(id: v.channelId, name: v.author, logo: logo)),
      child: Text(sub ? 'បានជាវ' : 'ជាវ'),
    );
  }
}

void _showComments(BuildContext context, VItem v) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => FutureBuilder<List<CommentItem>>(
        future: YtService.comments(v.id),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const <CommentItem>[];
          if (snap.hasError || list.isEmpty) {
            return const Center(child: Text('មិនមានមតិយោបល់'));
          }
          return ListView.separated(
            controller: scroll,
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (_, i) {
              final c = list[i];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LetterAvatar(c.author, radius: 15),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${c.author} · ${c.time}',
                          style: const TextStyle(fontSize: 12, color: Colors.white60)),
                      const SizedBox(height: 4),
                      Text(c.text, style: const TextStyle(fontSize: 13.5, height: 1.35)),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.thumb_up_outlined, size: 14, color: Colors.white60),
                        const SizedBox(width: 4),
                        Text(fmtCount(c.likes),
                            style: const TextStyle(fontSize: 12, color: Colors.white60)),
                        if (c.replies > 0) ...[
                          const SizedBox(width: 16),
                          Text('${c.replies} ការឆ្លើយតប',
                              style: const TextStyle(fontSize: 12, color: kAccent)),
                        ],
                      ]),
                    ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
    ),
  );
}
