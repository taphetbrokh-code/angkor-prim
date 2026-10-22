import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../player/player_controller.dart';
import '../services/library_store.dart';
import '../widgets/common.dart';
import 'search.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = LibraryStore.instance;
    final p = PlayerController.instance;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        titleSpacing: 12,
        title: const Text('បណ្ណាល័យ', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([lib, p]),
        builder: (context, _) => ListView(children: [
          // ---- history ----
          ListTile(
            title: const Text('ប្រវត្តិមើល',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VideoListScreen(
                        title: 'ប្រវត្តិមើល',
                        items: () => lib.history,
                        onRemove: lib.removeHistory,
                        onClear: lib.clearHistory,
                      ))),
              child: const Text('មើលទាំងអស់'),
            ),
          ),
          if (lib.history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('មិនទាន់មានប្រវត្តិ', style: TextStyle(color: Colors.white54)),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: lib.history.length > 20 ? 20 : lib.history.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final v = lib.history[i];
                  return InkWell(
                    onTap: () => p.play(v),
                    onLongPress: () => showVideoMenu(context, v),
                    child: SizedBox(
                      width: 150,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(fit: StackFit.expand, children: [
                              NetImage(v.thumbSmall),
                              Positioned(right: 4, bottom: 4, child: DurationBadge(v)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(v.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          const Divider(color: Colors.white12),
          _Entry(
            icon: Icons.watch_later_outlined,
            title: 'មើលពេលក្រោយ',
            count: lib.watchLater.length,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VideoListScreen(
                      title: 'មើលពេលក្រោយ',
                      items: () => lib.watchLater,
                      onRemove: lib.toggleSave,
                    ))),
          ),
          _Entry(
            icon: Icons.thumb_up_outlined,
            title: 'វីដេអូដែលបានចូលចិត្ត',
            count: lib.liked.length,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VideoListScreen(
                      title: 'វីដេអូដែលបានចូលចិត្ត',
                      items: () => lib.liked,
                      onRemove: lib.toggleLike,
                    ))),
          ),
          _Entry(
            icon: Icons.queue_music,
            title: 'ជួរចាក់បច្ចុប្បន្ន',
            count: p.queue.length,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VideoListScreen(
                      title: 'ជួរចាក់',
                      items: () => p.queue,
                      onRemove: p.removeFromQueue,
                    ))),
          ),
          const Divider(color: Colors.white12),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('ការកំណត់',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.skip_next_outlined),
            title: const Text('ចាក់បន្តស្វ័យប្រវត្តិ'),
            value: lib.autoplay,
            onChanged: lib.setAutoplay,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.headphones_outlined),
            title: const Text('ស្តាប់តែសំឡេង (សន្សំ data)'),
            subtitle: const Text('មិនបង្ហាញរូបភាពវីដេអូ'),
            value: lib.audioOnly,
            onChanged: p.setAudioOnly,
          ),
          ListTile(
            leading: const Icon(Icons.high_quality_outlined),
            title: const Text('គុណភាពវីដេអូលំនាំដើម'),
            trailing: DropdownButton<int>(
              value: const [144, 240, 360, 480, 720, 1080].contains(lib.maxHeight)
                  ? lib.maxHeight
                  : 720,
              underline: const SizedBox.shrink(),
              items: const [144, 240, 360, 480, 720, 1080]
                  .map((h) => DropdownMenuItem(value: h, child: Text('${h}p')))
                  .toList(),
              onChanged: (h) {
                if (h != null) lib.setMaxHeight(h);
              },
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('ANGKOR PRIM'),
            subtitle: Text('កំណែ 1.0.0 · ចាក់ផ្ទៃខាងក្រោយ & បិទអេក្រង់ស្តាប់បាន'),
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;
  const _Entry({required this.icon, required this.title, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text('$count វីដេអូ', style: const TextStyle(color: Colors.white54)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}

class VideoListScreen extends StatelessWidget {
  final String title;
  final List<VItem> Function() items;
  final void Function(VItem) onRemove;
  final VoidCallback? onClear;

  const VideoListScreen({
    super.key,
    required this.title,
    required this.items,
    required this.onRemove,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final p = PlayerController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([LibraryStore.instance, p]),
      builder: (context, _) {
        final list = List<VItem>.of(items());
        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (onClear != null && list.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('លុបទាំងអស់?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ទេ')),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('លុប')),
                        ],
                      ),
                    );
                    if (ok == true) onClear!();
                  },
                ),
            ],
          ),
          body: list.isEmpty
              ? const Center(child: Text('ទទេ', style: TextStyle(color: Colors.white54)))
              : ListView(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.white, foregroundColor: Colors.black),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('ចាក់ទាំងអស់'),
                          onPressed: () => p.playList(list, 0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.shuffle),
                          label: const Text('ច្របល់'),
                          onPressed: () {
                            final s = List<VItem>.of(list)..shuffle();
                            p.playList(s, 0);
                          },
                        ),
                      ),
                    ]),
                  ),
                  for (final (i, v) in list.indexed)
                    Dismissible(
                      key: ValueKey('${v.id}-$i'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red.shade900,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete),
                      ),
                      onDismissed: (_) => onRemove(v),
                      child: VideoTile(v, onTap: () => p.playList(list, i)),
                    ),
                  const SizedBox(height: 80),
                ]),
        );
      },
    );
  }
}
