import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'audio_service.dart';
import 'models/app_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Sport Music'),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Status',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _StatusRow(label: 'Connection', value: state.connectionStatus),
                            _StatusRow(label: 'Sport', value: state.currentSportLabel),
                            _StatusRow(label: 'Playlist', value: state.currentPlaylistName),
                            _StatusRow(label: 'Track', value: state.currentTrackName),
                            _StatusRow(
                              label: 'Playback',
                              value: state.isPlaying ? 'Playing' : 'Paused',
                            ),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: state.downloadProgress,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.downloadStatus,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.statusMessage,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                            const SizedBox(height: 20),
                            if (!state.areAllPlaylistsDownloaded) ...<Widget>[
                              FilledButton.icon(
                                onPressed: state.isDownloading ? null : state.downloadPlaylists,
                                icon: const Icon(Icons.download),
                                label: const Text('Download Music'),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: <Widget>[
                                FilledButton.tonalIcon(
                                  onPressed: state.isBusy ? null : state.handleConnectionButton,
                                  icon: Icon(
                                    state.isConnected
                                        ? Icons.link_off
                                        : Icons.bluetooth_connected,
                                  ),
                                  label: Text(
                                    state.isConnected ? 'Disconnect Device' : 'Link Device',
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: state.isBusy ? null : state.togglePlayback,
                                  icon: Icon(
                                    state.isPlaying ? Icons.pause : Icons.play_arrow,
                                  ),
                                  label: Text(
                                    state.isPlaying ? 'Pause' : 'Start',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Mock BLE'),
                              subtitle: const Text(
                                'Temporary demo mode for checking sport and music matching.',
                              ),
                              value: state.isMockModeEnabled,
                              onChanged: state.isBusy ? null : state.setMockMode,
                            ),
                            if (state.isMockModeEnabled) ...<Widget>[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: <Widget>[
                                  FilledButton.tonal(
                                    onPressed: state.isDownloading
                                        ? null
                                        : () => state.sendMockSport(SportType.resting),
                                    child: const Text('resting'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: state.isDownloading
                                        ? null
                                        : () => state.sendMockSport(SportType.walking),
                                    child: const Text('walking'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: state.isDownloading
                                        ? null
                                        : () => state.sendMockSport(SportType.running),
                                    child: const Text('running'),
                                  ),
                                ],
                              ),
                            ],
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
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
