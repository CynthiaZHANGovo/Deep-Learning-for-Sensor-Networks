import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

enum SportType {
  walking('walking', 'Walking Playlist', 'Moderate'),
  running('running', 'Running Playlist', 'Intense'),
  resting('resting', 'Resting Playlist', 'Calm');

  const SportType(this.value, this.playlistName, this.energyLabel);

  final String value;
  final String playlistName;
  final String energyLabel;

  static SportType? fromRawValue(String rawValue) {
    for (final sport in values) {
      if (sport.value == rawValue) {
        return sport;
      }
    }

    return null;
  }
}

class DownloadProgress {
  const DownloadProgress({
    required this.progress,
    required this.message,
  });

  final double progress;
  final String message;
}

class RemoteTrack {
  const RemoteTrack({
    required this.fileName,
    required this.title,
    required this.url,
  });

  final String fileName;
  final String title;
  final String url;
}

class AudioService {
  AudioService({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client() {
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      _playbackStateController.add(playerState.playing);
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final http.Client _httpClient;
  final StreamController<bool> _playbackStateController =
      StreamController<bool>.broadcast();

  late final StreamSubscription<PlayerState> _playerStateSubscription;

  final Map<SportType, List<RemoteTrack>> _remotePlaylists =
      const <SportType, List<RemoteTrack>>{
        SportType.resting: <RemoteTrack>[
          RemoteTrack(
            fileName: 'resting_calm_no_drums.mp3',
            title: 'Calm No Drums',
            url: 'https://samplelib.com/lib/preview/mp3/sample-15s.mp3',
          ),
        ],
        SportType.walking: <RemoteTrack>[
          RemoteTrack(
            fileName: 'walking_flute_drums.mp3',
            title: 'Flute and Drum Groove',
            url: 'https://samplelib.com/lib/preview/mp3/sample-12s.mp3',
          ),
        ],
        SportType.running: <RemoteTrack>[
          RemoteTrack(
            fileName: 'running_background_drums.mp3',
            title: 'Background Drums Drive',
            url: 'https://samplelib.com/lib/preview/mp3/sample-9s.mp3',
          ),
        ],
      };

  Stream<bool> get playbackStateStream => _playbackStateController.stream;

  SportType? _activeSport;
  String _currentTrackName = 'Not selected';

  SportType? get activeSport => _activeSport;
  bool get isPlaying => _player.playing;
  String get currentTrackName => _currentTrackName;

  String get currentPlaylistName {
    final sport = _activeSport;
    if (sport == null) {
      return 'Not selected';
    }

    return '${sport.playlistName} (${sport.energyLabel})';
  }

  String playlistLabelForSport(SportType sport) {
    return '${sport.playlistName} (${sport.energyLabel})';
  }

  int get playlistCount => _remotePlaylists.length;

  Future<Map<SportType, bool>> getDownloadStatus() async {
    final status = <SportType, bool>{};

    for (final sport in SportType.values) {
      status[sport] = await isPlaylistDownloaded(sport);
    }

    return status;
  }

  Future<bool> isPlaylistDownloaded(SportType sport) async {
    final tracks = _remotePlaylists[sport];
    if (tracks == null || tracks.isEmpty) {
      return false;
    }

    final directory = await _playlistDirectory(sport);
    for (final track in tracks) {
      final file = File('${directory.path}${Platform.pathSeparator}${track.fileName}');
      if (!await file.exists()) {
        return false;
      }

      if (await file.length() == 0) {
        return false;
      }
    }

    return true;
  }

  Future<void> downloadAllPlaylists({
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    for (var index = 0; index < SportType.values.length; index++) {
      final sport = SportType.values[index];
      final baseProgress = index / SportType.values.length;
      final span = 1 / SportType.values.length;

      await ensurePlaylistDownloaded(
        sport,
        onProgress: (progress) {
          onProgress?.call(
            DownloadProgress(
              progress: (baseProgress + (progress.progress * span)).clamp(0.0, 1.0),
              message: progress.message,
            ),
          );
        },
      );
    }

    onProgress?.call(
      const DownloadProgress(
        progress: 1,
        message: 'All playlists are ready for offline playback.',
      ),
    );
  }

  Future<void> ensurePlaylistDownloaded(
    SportType sport, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    final tracks = _remotePlaylists[sport];
    if (tracks == null || tracks.isEmpty) {
      throw StateError('No remote playlist configured for ${sport.value}.');
    }

    final directory = await _playlistDirectory(sport);
    var completedTracks = 0;

    for (final track in tracks) {
      final file = File('${directory.path}${Platform.pathSeparator}${track.fileName}');
      if (await file.exists() && await file.length() > 0) {
        completedTracks++;
        onProgress?.call(
          DownloadProgress(
            progress: completedTracks / tracks.length,
            message: '${playlistLabelForSport(sport)} already cached.',
          ),
        );
        continue;
      }

      onProgress?.call(
        DownloadProgress(
          progress: completedTracks / tracks.length,
          message: 'Downloading ${track.title}...',
        ),
      );

      final request = http.Request('GET', Uri.parse(track.url));
      final response = await _httpClient.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Download failed for ${track.fileName} with status ${response.statusCode}.',
        );
      }

      final sink = file.openWrite();
      var received = 0;
      final expected = response.contentLength;

      try {
        await for (final chunk in response.stream) {
          received += chunk.length;
          sink.add(chunk);

          final withinTrack = expected == null || expected == 0
              ? 0.5
              : (received / expected).clamp(0.0, 1.0);

          onProgress?.call(
            DownloadProgress(
              progress: ((completedTracks + withinTrack) / tracks.length).clamp(0.0, 1.0),
              message: 'Downloading ${track.title}...',
            ),
          );
        }
      } finally {
        await sink.close();
      }

      completedTracks++;
      onProgress?.call(
        DownloadProgress(
          progress: completedTracks / tracks.length,
          message: '${track.title} is ready.',
        ),
      );
    }
  }

  Future<bool> playPlaylistForSport(
    SportType sport, {
    bool autoDownload = false,
    void Function(DownloadProgress progress)? onDownloadProgress,
  }) async {
    if (_activeSport == sport) {
      return false;
    }

    if (!await isPlaylistDownloaded(sport)) {
      if (!autoDownload) {
        throw StateError('${playlistLabelForSport(sport)} has not been downloaded yet.');
      }

      await ensurePlaylistDownloaded(
        sport,
        onProgress: onDownloadProgress,
      );
    }

    final directory = await _playlistDirectory(sport);
    final tracks = _remotePlaylists[sport]!;
    final playlist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: tracks
          .map(
            (track) => AudioSource.file(
              '${directory.path}${Platform.pathSeparator}${track.fileName}',
            ),
          )
          .toList(growable: false),
    );

    await _player.setAudioSource(
      playlist,
      initialIndex: 0,
      initialPosition: Duration.zero,
    );
    await _player.setLoopMode(LoopMode.all);
    await _player.play();

    _activeSport = sport;
    _currentTrackName = tracks.first.title;
    return true;
  }

  Future<void> play() async {
    if (_player.audioSource != null) {
      await _player.play();
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    _activeSport = null;
    _currentTrackName = 'Not selected';
  }

  Future<void> dispose() async {
    await _playerStateSubscription.cancel();
    await _player.dispose();
    await _playbackStateController.close();
    _httpClient.close();
  }

  Future<Directory> _playlistDirectory(SportType sport) async {
    final rootDirectory = await getApplicationDocumentsDirectory();
    final playlistDirectory = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}playlists${Platform.pathSeparator}${sport.value}',
    );

    if (!await playlistDirectory.exists()) {
      await playlistDirectory.create(recursive: true);
    }

    return playlistDirectory;
  }
}
