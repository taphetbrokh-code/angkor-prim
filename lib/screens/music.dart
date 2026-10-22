import 'package:flutter/material.dart';

import '../main.dart';
import '../services/yt_service.dart';
import '../widgets/common.dart';
import 'search.dart';

/// Music tab: tapping a song plays the whole list in order, so it keeps
/// playing in the background with the screen off.
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  static const _genres = <(String, String, IconData)>[
    ('ថ្មីៗ', 'ចម្រៀងខ្មែរ ថ្មីៗ 2026', Icons.new_releases_outlined),
    ('ពេញនិយម', 'ចម្រៀងខ្មែរ ល្បីៗ', Icons.local_fire_department_outlined),
    ('មនោសញ្ចេតនា', 'ចម្រៀងខ្មែរ មនោសញ្ចេតនា', Icons.favorite_outline),
    ('Remix', 'khmer remix', Icons.speaker_outlined),
    ('បុរាណ', 'ចម្រៀងខ្មែរ បុរាណ ស៊ីន ស៊ីសាមុត', Icons.album_outlined),
    ('ប្រពៃណី', 'ភ្លេងការ ខ្មែរ', Icons.celebration_outlined),
    ('Chill', 'chill music playlist', Icons.nightlight_outlined),
    ('K-Pop', 'kpop', Icons.star_outline),
    ('Thai', 'thai song', Icons.music_note_outlined),
    ('English', 'english songs top hits', Icons.public),
    ('ធម៌', 'ធម៌ សូត្រ', Icons.self_improvement),
  ];
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final g = _genres[_sel];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const Text('តន្ត្រី', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SearchScreen(musicMode: true))),
          ),
        ],
      ),
      backgroundColor: kBg,
      body: PagedVideoList(
        key: ValueKey(g.$2),
        compact: true,
        playAsList: true,
        pagerBuilder: () => SearchPager(g.$2),
        header: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _genres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final on = i == _sel;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _sel = i),
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: on
                            ? [kAccent, kAccentDeep]
                            : [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(_genres[i].$3, size: 22),
                        Text(_genres[i].$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'ចុចលើបទណាមួយ វានឹងចាក់បន្តរហូត — អាចបិទអេក្រង់ ស្តាប់បាន',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
        ]),
      ),
    );
  }
}
