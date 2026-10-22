import 'package:flutter/material.dart';

import '../main.dart';
import '../services/yt_service.dart';
import '../widgets/common.dart';
import 'search.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _chips = <(String, String)>[
    ('ទាំងអស់', 'ពេញនិយម ថ្មីៗ'),
    ('ចម្រៀងខ្មែរ', 'ចម្រៀងខ្មែរ ថ្មី'),
    ('តន្ត្រី', 'music video'),
    ('ព័ត៌មាន', 'ព័ត៌មាន ខ្មែរ ថ្ងៃនេះ'),
    ('កំប្លែង', 'កំប្លែង ខ្មែរ'),
    ('ភាពយន្ត', 'រឿងភាគ ខ្មែរ'),
    ('ហ្គេម', 'gaming'),
    ('ផ្ទាល់', 'live ខ្មែរ'),
    ('ធ្វើម្ហូប', 'ធ្វើម្ហូប ខ្មែរ'),
    ('កីឡា', 'កីឡា highlights'),
    ('Podcast', 'podcast ខ្មែរ'),
  ];
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final q = _chips[_sel].$2;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const AppLogo(),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final on = i == _sel;
                return ChoiceChip(
                  label: Text(_chips[i].$1),
                  selected: on,
                  showCheckmark: false,
                  selectedColor: Colors.white,
                  labelStyle: TextStyle(color: on ? Colors.black : Colors.white, fontSize: 13),
                  backgroundColor: const Color(0xFF272727),
                  side: BorderSide.none,
                  onSelected: (_) => setState(() => _sel = i),
                );
              },
            ),
          ),
        ),
      ),
      backgroundColor: kBg,
      body: PagedVideoList(
        key: ValueKey(q),
        pagerBuilder: () => SearchPager(q),
      ),
    );
  }
}
