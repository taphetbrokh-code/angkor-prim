import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../player/player_controller.dart';
import '../services/library_store.dart';
import '../services/yt_service.dart';
import '../widgets/common.dart';

class SearchScreen extends StatefulWidget {
  final bool musicMode;
  const SearchScreen({super.key, this.musicMode = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  String? _query; // submitted query
  List<String> _sugs = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  static final _idRe = RegExp(
      r'(?:youtube\.com/(?:watch\?v=|shorts/|live/|embed/)|youtu\.be/)([A-Za-z0-9_-]{11})');

  void _submit(String q) {
    q = q.trim();
    if (q.isEmpty) return;
    _focus.unfocus();

    // A pasted video link: play it directly.
    final m = _idRe.firstMatch(q);
    if (m != null) {
      final id = m.group(1)!;
      toast(context, 'កំពុងបើក...');
      YtService.videoRaw(id).then((v) {
        PlayerController.instance.play(YtService.fromVideo(v));
      }).catchError((_) {
        if (mounted) toast(context, 'មិនអាចបើកតំណនេះបានទេ');
      });
      return;
    }

    LibraryStore.instance.addSearch(q);
    _ctl.text = q;
    setState(() => _query = widget.musicMode ? '$q song' : q);
  }

  void _onChanged(String s) {
    setState(() => _query = null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final r = await YtService.suggestions(s);
      if (mounted && _ctl.text == s) setState(() => _sugs = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = LibraryStore.instance;
    final typing = _query == null;
    final history = _ctl.text.isEmpty
        ? lib.searches
        : lib.searches.where((e) => e.contains(_ctl.text)).take(3).toList();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctl,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _submit,
          onTap: () => setState(() => _query = null),
          decoration: InputDecoration(
            hintText: widget.musicMode ? 'ស្វែងរកបទចម្រៀង...' : 'ស្វែងរក ឬ បិទភ្ជាប់តំណ YouTube',
            filled: true,
            fillColor: const Color(0xFF272727),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _ctl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _ctl.clear();
                      setState(() {
                        _query = null;
                        _sugs = [];
                      });
                      _focus.requestFocus();
                    },
                  ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => _submit(_ctl.text)),
        ],
      ),
      body: typing
          ? ListView(children: [
              for (final h in history)
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(h),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => lib.removeSearch(h)),
                  ),
                  onTap: () => _submit(h),
                ),
              if (_ctl.text.isNotEmpty)
                for (final s in _sugs.where((e) => !history.contains(e)))
                  ListTile(
                    leading: const Icon(Icons.search),
                    title: Text(s),
                    trailing: IconButton(
                      icon: const Icon(Icons.north_west, size: 18),
                      onPressed: () {
                        _ctl.text = '$s ';
                        _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
                        _onChanged(_ctl.text);
                      },
                    ),
                    onTap: () => _submit(s),
                  ),
            ])
          : PagedVideoList(
              key: ValueKey(_query),
              compact: widget.musicMode,
              playAsList: widget.musicMode,
              pagerBuilder: () => SearchPager(_query!),
            ),
    );
  }
}
