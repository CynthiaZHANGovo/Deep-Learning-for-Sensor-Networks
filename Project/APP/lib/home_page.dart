import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sport Music'),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    'Live Status',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: state.isBusy ? null : state.handleConnectionButton,
                                  icon: Icon(
                                    state.isConnected
                                        ? Icons.link_off_rounded
                                        : Icons.bluetooth_connected_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    state.isConnected ? 'Disconnect' : 'Link Device',
                                  ),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7FAF9),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFD7E6E0)),
                              ),
                              child: Column(
                                children: <Widget>[
                                  _StatusRow(label: 'Connection', value: state.connectionStatus),
                                  _StatusRow(label: 'Sport', value: state.currentSportLabel),
                                  _StatusRow(label: 'Track', value: state.currentTrackName),
                                  _StatusRow(
                                    label: 'Playback',
                                    value: state.isPlaying ? 'Playing' : 'Paused',
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    'Playlist download',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message: 'Clear download cache',
                                  child: OutlinedButton(
                                    onPressed: state.isDownloading ? null : state.clearDownloadCache,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(36, 36),
                                      padding: const EdgeInsets.all(8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Download music',
                                  child: FilledButton(
                                    onPressed: state.isDownloading ? null : state.downloadPlaylists,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(36, 36),
                                      padding: const EdgeInsets.all(8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Icon(Icons.download_rounded, size: 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: state.downloadProgress,
                                minHeight: 10,
                                backgroundColor: const Color(0xFFDCE9E4),
                                color: const Color(0xFF0F766E),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(state.downloadStatus),
                            const SizedBox(height: 6),
                            Text(
                              state.statusMessage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 26),
                            Center(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: state.isBusy ? null : state.togglePlayback,
                                child: Ink(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E),
                                    shape: BoxShape.circle,
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: const Color(0xFF0F766E).withValues(alpha: 0.22),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    state.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5C726C),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF163C35),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
