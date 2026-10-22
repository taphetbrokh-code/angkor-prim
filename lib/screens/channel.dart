import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../services/library_store.dart';
import '../services/yt_service.dart';
import '../widgets/common.dart';

class ChannelScreen extends StatefulWidget {
  final String channelId;
  final String name;
  const ChannelScreen({super.key, required this.channelId, required this.name});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  ChannelInfo? _info;

  @override
  void initState() {
    super.initState();
    YtService.channel(widget.channelId).then((c) {
      if (mounted) setState(() => _info = c);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final title = info?.title ?? widget.name;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: PagedVideoList(
        pagerBuilder: () => UploadsPager(widget.channelId),
        playAsList: true,
        compact: true,
        header: ListenableBuilder(
          listenable: LibraryStore.instance,
          builder: (context, _) {
            final lib = LibraryStore.instance;
            final sub = lib.isSub(widget.channelId);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (info != null && info.bannerUrl.isNotEmpty)
                AspectRatio(aspectRatio: 6.2, child: NetImage(info.bannerUrl)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  LetterAvatar(title, url: info?.logoUrl, radius: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      if (info?.subscribers != null)
                        Text('អ្នកជាវ ${fmtCount(info!.subscribers!)} នាក់',
                            style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: sub ? Colors.white12 : Colors.white,
                      foregroundColor: sub ? Colors.white : Colors.black,
                    ),
                    onPressed: () => lib.toggleSub(ChannelRef(
                        id: widget.channelId, name: title, logo: info?.logoUrl ?? '')),
                    child: Text(sub ? 'បានជាវ' : 'ជាវ'),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: Text('វីដេអូ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
