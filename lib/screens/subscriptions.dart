import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../player/player_controller.dart';
import '../services/library_store.dart';
import '../services/yt_service.dart';
import '../widgets/common.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<VItem>? _feed;
  bool _loading = false;
  String _subsKey = '';

  @override
  void initState() {
    super.initState();
    LibraryStore.instance.addListener(_onLib);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    LibraryStore.instance.removeListener(_onLib);
    super.dispose();
  }

  void _onLib() {
    final key = LibraryStore.instance.subs.map((e) => e.id).join(',');
    if (key != _subsKey) _load();
  }

  Future<void> _load() async {
    final subs = LibraryStore.instance.subs.take(20).toList();
    _subsKey = LibraryStore.instance.subs.map((e) => e.id).join(',');
    if (!mounted) return;
    if (subs.isEmpty) {
      setState(() => _feed = []);
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);
    final results = await Future.wait(subs.map((s) async {
      try {
        final page = await UploadsPager(s.id).load();
        return page.take(6).toList();
      } catch (_) {
        return <VItem>[];
      }
    }));
    final all = results.expand((e) => e).toList()
      ..sort((a, b) => (b.dateMs ?? 0).compareTo(a.dateMs ?? 0));
    if (mounted) {
      setState(() {
        _feed = all;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = LibraryStore.instance;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        titleSpacing: 12,
        title: const Text('ការជាវ', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: lib.subs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.subscriptions_outlined, size: 56, color: Colors.white38),
                  SizedBox(height: 12),
                  Text('មិនទាន់ជាវឆានែលណាមួយទេ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('ចុច "ជាវ" នៅក្រោមវីដេអូ ដើម្បីឃើញវីដេអូថ្មីៗនៅទីនេះ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54)),
                ]),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(children: [
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: lib.subs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, i) {
                      final s = lib.subs[i];
                      return GestureDetector(
                        onTap: () => openChannel(s.id, s.name),
                        child: SizedBox(
                          width: 64,
                          child: Column(children: [
                            LetterAvatar(s.name, url: s.logo, radius: 26),
                            const SizedBox(height: 6),
                            Text(s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                if (_loading && (_feed == null || _feed!.isEmpty))
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                for (final (i, v) in (_feed ?? const <VItem>[]).indexed)
                  VideoCard(v, onTap: () => PlayerController.instance.playList(_feed!, i)),
                const SizedBox(height: 80),
              ]),
            ),
    );
  }
}
