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
    _currentIndexSubscription = _player.currentIndexStream.listen((index) {
      _currentTrackIndex = index;
      _syncCurrentTrackMetadata();
      _playbackStateController.add(_player.playing);
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final http.Client _httpClient;
  final StreamController<bool> _playbackStateController =
      StreamController<bool>.broadcast();

  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<int?> _currentIndexSubscription;

  final Map<SportType, List<RemoteTrack>> _remotePlaylists =
      const <SportType, List<RemoteTrack>>{
        SportType.resting: <RemoteTrack>[
          RemoteTrack(
            fileName: 'resting_calm_piano_v2.mp3',
            title: 'Calm Piano',
            url: 'https://orangefreesounds.com/wp-content/uploads/2023/04/Calm-piano-background-music-free.mp3',
          ),
          RemoteTrack(
            fileName: 'resting_soft_piano_v2.mp3',
            title: 'Soft Piano Song',
            url: 'https://www.orangefreesounds.com/wp-content/uploads/2021/06/Soft-piano-song.mp3',
          ),
          RemoteTrack(
            fileName: 'resting_dreamy_ambient_v2.mp3',
            title: 'Dreamy Ambient Music',
            url: 'https://orangefreesounds.com/wp-content/uploads/2023/06/Dreamy-ambient-music.mp3',
          ),
        ],
        SportType.walking: <RemoteTrack>[
          RemoteTrack(
            fileName: 'walking_uplifting_v2.mp3',
            title: 'Uplifting Instrumental Music',
            url: 'https://www.orangefreesounds.com/wp-content/uploads/2021/07/Uplifting-instrumental-music.mp3',
          ),
          RemoteTrack(
            fileName: 'walking_groovy_day_v2.mp3',
            title: 'Groovy Day',
            url: 'https://www.orangefreesounds.com/wp-content/uploads/2016/12/Groovy-day-infomercial-music.mp3',
          ),
          RemoteTrack(
            fileName: 'walking_motivational_v2.mp3',
            title: 'Motivational Inspiring Music',
            url: 'https://orangefreesounds.com/wp-content/uploads/2023/03/Motivational-inspiring-music.mp3',
          ),
        ],
        SportType.running: <RemoteTrack>[
          RemoteTrack(
            fileName: 'running_free_electronic_v4.mp3',
            title: 'Free Electronic Music',
            url: 'https://orangefreesounds.com/wp-content/uploads/2023/09/Free-electronic-music.mp3',
          ),
          RemoteTrack(
            fileName: 'running_free_inspirational_v3.mp3',
            title: 'Free Inspirational Music',
            url: 'https://orangefreesounds.com/wp-content/uploads/2023/08/Free-inspirational-music.mp3',
          ),
          RemoteTrack(
            fileName: 'running_groovy_electronic_v4.mp3',
            title: 'Groovy Electronic Background Music',
            url: 'https://www.orangefreesounds.com/wp-content/uploads/2022/03/Groovy-electronic-background-music.mp3',
          ),
        ],
      };

  Stream<bool> get playbackStateStream => _playbackStateController.stream;

  SportType? _activeSport;
  String _currentTrackName = 'Not selected';
  int? _currentTrackIndex;

  SportType? get activeSport => _activeSport;
  bool get isPlaying => _player.playing;
  String get currentTrackName => _currentTrackName;
  int? get currentTrackIndex => _currentTrackIndex;

  String get currentPlaylistName {
    final sport = _activeSport;
    if (sport == null) {
      return 'Not selected';
    }

    return sport.playlistName;
  }

  String playlistLabelForSport(SportType sport) {
    return sport.playlistName;
  }

  int get playlistCount => _remotePlaylists.length;

  List<RemoteTrack> tracksForSport(SportType sport) {
    return List<RemoteTrack>.unmodifiable(_remotePlaylists[sport] ?? const <RemoteTrack>[]);
  }

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

  Future<void> clearDownloadCache() async {
    await stop();

    final rootDirectory = await getApplicationDocumentsDirectory();
    final playlistsDirectory = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}playlists',
    );

    if (await playlistsDirectory.exists()) {
      await playlistsDirectory.delete(recursive: true);
    }
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
    if (_activeSport == sport && _currentTrackIndex == 0) {
      return false;
    }

    return playTrackForSport(
      sport,
      0,
      autoDownload: autoDownload,
      onDownloadProgress: onDownloadProgress,
    );
  }

  Future<bool> playTrackForSport(
    SportType sport,
    int trackIndex, {
    bool autoDownload = false,
    void Function(DownloadProgress progress)? onDownloadProgress,
  }) async {
    final tracks = _remotePlaylists[sport];
    if (tracks == null || tracks.isEmpty) {
      throw StateError('No remote playlist configured for ${sport.value}.');
    }

    if (trackIndex < 0 || trackIndex >= tracks.length) {
      throw RangeError.index(trackIndex, tracks, 'trackIndex');
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
      initialIndex: trackIndex,
      initialPosition: Duration.zero,
    );
    await _player.setLoopMode(LoopMode.all);
    _activeSport = sport;
    _currentTrackIndex = trackIndex;
    _syncCurrentTrackMetadata();
    await _player.play();
    _playbackStateController.add(_player.playing);
    return true;
  }

  Future<void> play() async {
    if (_player.audioSource != null) {
      await _player.play();
      _playbackStateController.add(_player.playing);
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _playbackStateController.add(_player.playing);
  }

  Future<void> stop() async {
    await _player.stop();
    _activeSport = null;
    _currentTrackName = 'Not selected';
    _currentTrackIndex = null;
    _playbackStateController.add(_player.playing);
  }

  Future<void> dispose() async {
    await _playerStateSubscription.cancel();
    await _currentIndexSubscription.cancel();
    await _player.dispose();
    await _playbackStateController.close();
    _httpClient.close();
  }

  void _syncCurrentTrackMetadata() {
    final sport = _activeSport;
    if (sport == null) {
      _currentTrackName = 'Not selected';
      return;
    }

    final tracks = _remotePlaylists[sport];
    if (tracks == null || tracks.isEmpty) {
      _currentTrackName = 'Not selected';
      return;
    }

    final index = _currentTrackIndex ?? 0;
    if (index < 0 || index >= tracks.length) {
      _currentTrackName = tracks.first.title;
      return;
    }

    _currentTrackName = tracks[index].title;
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
