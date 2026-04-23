import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio_service.dart';
import '../ble_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required BleService bleService,
    required AudioService audioService,
  })  : _bleService = bleService,
        _audioService = audioService;

  final BleService _bleService;
  final AudioService _audioService;

  StreamSubscription<String>? _bleStatusSubscription;
  StreamSubscription<String>? _bleSportSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<bool>? _playbackSubscription;

  bool _isConnected = false;
  bool _isBusy = false;
  bool _isDownloading = false;
  bool _isRoutingSportChange = false;
  bool _isMockModeEnabled = false;
  String _connectionStatus = 'Disconnected';
  String _statusMessage = 'Ready to link SportMusicNano.';
  String _downloadStatus = 'Playlists are not downloaded yet.';
  SportType? _targetSport;
  double _downloadProgress = 0;
  Map<SportType, bool> _downloadedPlaylists = <SportType, bool>{};

  bool get isConnected => _isConnected;
  bool get isBusy => _isBusy;
  bool get isDownloading => _isDownloading;
  bool get isMockModeEnabled => _isMockModeEnabled;
  bool get isPlaying => _audioService.isPlaying;
  bool get hasDiscoveredDevice => _bleService.hasDiscoveredDevice;
  bool get areAllPlaylistsDownloaded => downloadedPlaylistCount == totalPlaylistCount;
  String get connectionStatus => _connectionStatus;
  String get statusMessage => _statusMessage;
  String get downloadStatus => _downloadStatus;
  String get currentSportLabel => _audioService.activeSport?.value ?? 'Waiting for data';
  String get currentPlaylistName => _audioService.currentPlaylistName;
  String get currentTrackName => _audioService.currentTrackName;
  double get downloadProgress => _downloadProgress;
  int get downloadedPlaylistCount =>
      _downloadedPlaylists.values.where((downloaded) => downloaded).length;
  int get totalPlaylistCount => _audioService.playlistCount;

  Future<void> initialize() async {
    _bleStatusSubscription = _bleService.statusStream.listen((message) {
      _statusMessage = message;
      notifyListeners();
    });

    _bleSportSubscription = _bleService.sportStream.listen((rawSport) {
      if (_isMockModeEnabled) {
        return;
      }

      unawaited(_handleSportUpdate(rawSport));
    });

    _connectionSubscription = _bleService.connectionStream.listen((connected) {
      _isConnected = connected;
      _connectionStatus = connected ? 'Connected' : 'Disconnected';
      notifyListeners();
    });

    _playbackSubscription =
        _audioService.playbackStateStream.listen((_) => notifyListeners());

    await refreshDownloads();
  }

  Future<void> handleConnectionButton() async {
    if (_isConnected) {
      await disconnect();
      return;
    }

    await _runBusyTask(() async {
      _connectionStatus = 'Scanning';
      notifyListeners();
      await _bleService.startScan();

      if (!hasDiscoveredDevice) {
        _connectionStatus = 'Disconnected';
        return;
      }

      _connectionStatus = 'Connecting';
      notifyListeners();
      await _bleService.connectToTargetDevice();
    });
  }

  Future<void> disconnect() async {
    await _runBusyTask(() async {
      await _bleService.disconnect();
      await _audioService.stop();
      _resetSportRouting();
      _connectionStatus = 'Disconnected';
      _statusMessage = 'Disconnected.';
    });
  }

  Future<void> setMockMode(bool enabled) async {
    if (_isMockModeEnabled == enabled) {
      return;
    }

    _isMockModeEnabled = enabled;

    if (enabled) {
      await _bleService.disconnect(emitStatus: false);
      _isConnected = false;
      _connectionStatus = 'Disconnected';
      _statusMessage = 'Manual control ready.';
    } else {
      _resetSportRouting();
      _statusMessage = 'Ready to link SportMusicNano.';
    }

    notifyListeners();
  }

  Future<void> sendMockSport(SportType sport) async {
    if (!_isMockModeEnabled) {
      return;
    }

    await _runBusyTask(() async {
      _targetSport = null;
      _isRoutingSportChange = true;
      _statusMessage = 'Switching to ${sport.playlistName}...';
      notifyListeners();

      try {
        final didSwitch = await _audioService.playPlaylistForSport(
          sport,
          autoDownload: true,
          onDownloadProgress: (progress) {
            _isDownloading = true;
            _downloadProgress = progress.progress;
            _downloadStatus = progress.message;
            notifyListeners();
          },
        );

        await refreshDownloads();
        _isDownloading = false;
        _statusMessage = didSwitch
            ? 'Switched to ${sport.playlistName}.'
            : '${sport.playlistName} is already active.';
      } catch (error) {
        _isDownloading = false;
        _statusMessage = 'Audio playback error: $error';
      } finally {
        _isRoutingSportChange = false;
      }

      notifyListeners();
    });
  }

  Future<void> togglePlayback() async {
    if (isPlaying) {
      await pause();
      return;
    }

    await play();
  }

  Future<void> play() async {
    try {
      await _audioService.play();
      notifyListeners();
    } catch (error) {
      _statusMessage = 'Unable to play audio: $error';
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _audioService.pause();
    notifyListeners();
  }

  Future<void> downloadPlaylists() async {
    if (_isDownloading) {
      return;
    }

    _isDownloading = true;
    _downloadProgress = 0;
    _downloadStatus = 'Preparing playlist downloads...';
    notifyListeners();

    try {
      await _audioService.downloadAllPlaylists(
        onProgress: (progress) {
          _downloadProgress = progress.progress;
          _downloadStatus = progress.message;
          notifyListeners();
        },
      );
      await refreshDownloads();
      _statusMessage = 'Playlist download completed.';
    } catch (error) {
      _downloadStatus = 'Download failed: $error';
      _statusMessage = _downloadStatus;
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> clearDownloadCache() async {
    if (_isDownloading) {
      return;
    }

    _isDownloading = true;
    _downloadProgress = 0;
    _downloadStatus = 'Clearing downloaded music cache...';
    notifyListeners();

    try {
      await _audioService.clearDownloadCache();
      _resetSportRouting();
      await refreshDownloads();
      _statusMessage = 'Downloaded music cache cleared.';
    } catch (error) {
      _downloadStatus = 'Failed to clear cache: $error';
      _statusMessage = _downloadStatus;
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDownloads() async {
    _downloadedPlaylists = await _audioService.getDownloadStatus();

    final downloadedCount =
        _downloadedPlaylists.values.where((downloaded) => downloaded).length;

    if (downloadedCount == _audioService.playlistCount) {
      _downloadProgress = 1;
      _downloadStatus = 'All playlists are cached on the device.';
    } else if (downloadedCount == 0) {
      _downloadProgress = 0;
      _downloadStatus = 'Playlists are not downloaded yet.';
    } else {
      _downloadProgress = downloadedCount / _audioService.playlistCount;
      _downloadStatus =
          '$downloadedCount of ${_audioService.playlistCount} playlists are cached.';
    }

    notifyListeners();
  }

  Future<void> _handleSportUpdate(String rawSport) async {
    final sport = SportType.fromRawValue(rawSport);
    if (sport == null) {
      _statusMessage = 'Ignored unknown sport value: $rawSport';
      notifyListeners();
      return;
    }

    _targetSport = sport;
    notifyListeners();

    if (_isRoutingSportChange) {
      _statusMessage = 'Updating music to ${sport.value}...';
      notifyListeners();
      return;
    }

    _isRoutingSportChange = true;

    try {
      while (_targetSport != null) {
        final nextSport = _targetSport!;
        _targetSport = null;

        if (_audioService.activeSport == nextSport) {
          _statusMessage = '${nextSport.playlistName} is already active.';
          notifyListeners();
          continue;
        }

        _statusMessage = 'Switching to ${nextSport.playlistName}...';
        notifyListeners();

        final didSwitch = await _audioService.playPlaylistForSport(
          nextSport,
          autoDownload: true,
          onDownloadProgress: (progress) {
            if (_targetSport != null) {
              return;
            }
            _isDownloading = true;
            _downloadProgress = progress.progress;
            _downloadStatus = progress.message;
            notifyListeners();
          },
        );

        if (!didSwitch && _audioService.activeSport != nextSport) {
          _statusMessage = 'Audio source did not switch to ${nextSport.value}.';
          notifyListeners();
          continue;
        }

        await refreshDownloads();
        _isDownloading = false;
        _statusMessage = didSwitch
            ? 'Switched to ${nextSport.playlistName}.'
            : '${nextSport.playlistName} is already active.';
        notifyListeners();
      }
    } catch (error) {
      _isDownloading = false;
      _statusMessage = 'Audio playback error: $error';
    } finally {
      _isRoutingSportChange = false;
    }
  }

  void _resetSportRouting() {
    _targetSport = null;
  }

  Future<void> _runBusyTask(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }

    _isBusy = true;
    notifyListeners();

    try {
      await action();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_bleStatusSubscription?.cancel());
    unawaited(_bleSportSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(_playbackSubscription?.cancel());
    unawaited(_bleService.dispose());
    unawaited(_audioService.dispose());
    super.dispose();
  }
}
