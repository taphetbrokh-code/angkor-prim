import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models.dart';
import '../player/player_controller.dart';
import 'common.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = PlayerController.instance;
    return ListenableBuilder(listenable: p, builder: (context, _) => _build(p));
  }

  Widget _build(PlayerController p) {
    final v = p.current;
    if (v == null) return const SizedBox.shrink();
    final vc = p.video;
    return Material(
      color: kSurface,
      child: InkWell(
        onTap: p.expand,
        child: GestureDetector(
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -200) p.expand();
            if ((d.primaryVelocity ?? 0) > 200) p.close();
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            StreamBuilder<Duration>(
              stream: p.audio.positionStream,
              builder: (c, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = p.audio.duration ?? v.duration;
                final val = dur.inMilliseconds > 0
                    ? clampD(pos.inMilliseconds / dur.inMilliseconds, 0.0, 1.0)
                    : 0.0;
                return LinearProgressIndicator(
                  value: val,
                  minHeight: 2,
                  backgroundColor: Colors.white12,
                  color: kAccent,
                );
              },
            ),
            SizedBox(
              height: 60,
              child: Row(children: [
                SizedBox(
                  width: 107,
                  height: 60,
                  child: ColoredBox(
                    color: Colors.black,
                    child: (vc != null && vc.value.isInitialized)
                        ? Center(
                            child: AspectRatio(
                              aspectRatio: vc.value.aspectRatio,
                              child: VideoPlayer(vc),
                            ),
                          )
                        : NetImage(v.thumbSmall),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(v.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.white60)),
                    ],
                  ),
                ),
                StreamBuilder<PlayerState>(
                  stream: p.audio.playerStateStream,
                  builder: (c, snap) {
                    final s = snap.data;
                    final busy = p.loading ||
                        s?.processingState == ProcessingState.loading ||
                        s?.processingState == ProcessingState.buffering;
                    if (busy) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    return IconButton(
                      icon: Icon(
                          (s?.playing ?? false) ? Icons.pause : Icons.play_arrow,
                          size: 30),
                      onPressed: p.togglePlay,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 26),
                  onPressed: p.next,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: p.close,
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
