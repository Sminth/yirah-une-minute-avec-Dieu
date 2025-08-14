import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

enum VerseMode { fixed, random }

class HomeController with ChangeNotifier {
  HomeController();

  void _log(String message) {
    if (kDebugMode) debugPrint('[Verses] ' + message);
  }

  // API.Bible integration
  static const String _apiBibleKey = '81bb8705f749384182340c6cd218fad0';
  static const String _apiBibleBase = 'https://api.scripture.api.bible/v1';
  String? _apiBibleId; // Resolved LSG bible id (cached per session)

  // Playback / timer
  bool isRunning = false;
  Duration total = Duration.zero;
  Duration remaining = Duration.zero;
  bool isAudioPlaying = false;
  bool isMuted = false;
  static const double _defaultVolume = 0.4;
  final AudioPlayer _player = AudioPlayer();
  Timer? _ticker;
  String? currentTrackName;
  String? _currentTrackPath;
  String? get currentTrackFilePath => _currentTrackPath;
  StreamSubscription<void>? _notifSub;
  // Audio mode: fixed file or random
  bool audioRandom = true;
  String? fixedAudioPath;
  Duration? customQuickDuration;
  Duration selectedQuickDuration = const Duration(minutes: 1);

  // Verses
  VerseMode verseMode = VerseMode.fixed;
  Timer? _verseRotator;
  int _verseIndex = 0;
  String verseText =
      'Demeurez en moi, et je demeurerai en vous. Je suis le cep, vous êtes les sarments; celui qui demeure en moi et en qui je demeure porte beaucoup de fruit; sans moi vous ne pouvez rien faire.';
  String verseRef = 'Jean 15:4-5';
  final List<Map<String, String>> frVersePool = [
    {
      'ref': 'Jean 15:4-5',
      'text':
          'Demeurez en moi, et je demeurerai en vous. Je suis le cep, vous êtes les sarments; celui qui demeure en moi et en qui je demeure porte beaucoup de fruit; sans moi vous ne pouvez rien faire.'
    },
    {
      'ref': 'Psaume 23:1',
      'text': 'L’Éternel est mon berger: je ne manquerai de rien.'
    },
    {
      'ref': 'Philippiens 4:6',
      'text':
          'Ne vous inquiétez de rien; mais en toute chose faites connaître vos besoins à Dieu par des prières et des supplications, avec des actions de grâces.'
    },
  ];

  // Inspiration/messages (non-verse) pool
  final List<String> inspirationMessages = [
    "Mon enfant, ne t'éloigne pas de ma Parole; lis-la quotidiennement.",
    "Mon enfant, j'ai donné ma vie pour toi; tu es précieux à mes yeux.",
    "Je suis avec toi; ne crains pas, je te fortifie et je te soutiens.",
    "Repose-toi en moi; je suis ta paix et ton refuge.",
    "Approche-toi de moi, et je m'approcherai de toi.",
  ];

  Map<String, String> getRandomInspiration() {
    if (inspirationMessages.isEmpty) {
      return {
        'title': 'Inspiration',
        'text': "Dieu t'aime et marche avec toi aujourd'hui."
      };
    }
    final int i = math.Random().nextInt(inspirationMessages.length);
    return {'title': 'Inspiration', 'text': inspirationMessages[i]};
  }

  // Quotes pool (citation/author)
  final List<Map<String, String>> quotePool = [
    {
      'label': 'Charles Spurgeon',
      'content':
          "Commencez votre journée avec Dieu; vous aurez moins de raisons de l'oublier ensuite."
    },
    {
      'label': 'Billy Graham',
      'content':
          "La prière n'est pas une préparation à la bataille; la prière est la bataille."
    },
    {
      'label': 'Elisabeth Elliot',
      'content':
          "Dieu n'est jamais en retard; notre impatience nous empêche souvent de voir sa fidélité."
    },
  ];

  // Unified items: { type: verse|quote|inspiration, label: title, content: message }
  List<Map<String, String>> getAllSkyDropItems() {
    final List<Map<String, String>> items = [];
    // Verses from current pool
    for (final v in frVersePool) {
      final String label = v['ref'] ?? 'Verset';
      final String content = v['text'] ?? '';
      items.add({'type': 'verse', 'label': label, 'content': content});
    }
    // Inspirations
    for (final s in inspirationMessages) {
      items.add({'type': 'inspiration', 'label': 'Inspiration', 'content': s});
    }
    // Quotes
    for (final q in quotePool) {
      items.add({
        'type': 'quote',
        'label': q['label'] ?? 'Citation',
        'content': q['content'] ?? ''
      });
    }
    return items;
  }

  Map<String, String> getRandomSkyDropItem() {
    final items = getAllSkyDropItems();
    if (items.isEmpty) {
      return {
        'type': 'inspiration',
        'label': 'Inspiration',
        'content': "Dieu t'aime et marche avec toi aujourd'hui."
      };
    }
    final int i = math.Random().nextInt(items.length);
    return items[i];
  }

  // Notifications (global)
  static final FlutterLocalNotificationsPlugin fln =
      FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;
  static bool _pendingStartOneMinute = false;
  static final StreamController<void> _startOneMinuteStreamController =
      StreamController<void>.broadcast();

  // Pre-initialize notifications early (before runApp) so notification taps are caught
  static Future<void> preInitializeNotifications() async {
    if (_notificationsInitialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'twin_actions',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('start_1m_action', 'Prier 1m'),
          ],
        ),
      ],
    );
    final InitializationSettings initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await fln.initialize(initSettings,
        onDidReceiveNotificationResponse: (response) async {
      final String? payload = response.payload;
      final String actionId = response.actionId ?? '';
      if (payload == 'start_1m' || actionId == 'start_1m_action') {
        _pendingStartOneMinute = true;
        // Notify any active controller
        _startOneMinuteStreamController.add(null);
      }
    });

    // Handle app launch from notification (terminated state)
    final NotificationAppLaunchDetails? launchDetails =
        await fln.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final response = launchDetails!.notificationResponse;
      final String? payload = response?.payload;
      final String actionId = response?.actionId ?? '';
      if (payload == 'start_1m' || actionId == 'start_1m_action') {
        _pendingStartOneMinute = true;
      }
    }

    _notificationsInitialized = true;
  }

  static const List<String> _audioUrls = [
    // 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    // 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
  ];

  Future<void> init() async {
    _log('init');
    await _initNotifications();
    await _loadPrefs();
    _applyVerseMode();
    // Ensure bundled assets are available alongside downloaded files
    // so that the picker and random play can use them.
    await _ensureLocalAudioFiles();
    await _setupAudio();
    _player.onPlayerComplete.listen((event) async {
      // Chain next track while timer is running
      if (isRunning && remaining > Duration.zero) {
        await _playNextTrack();
      } else {
        isAudioPlaying = false;
        notifyListeners();
      }
    });

    // If a tap/action was received before the controller existed, honor it now
    if (_pendingStartOneMinute) {
      _pendingStartOneMinute = false;
      startSession(const Duration(minutes: 1));
    }

    // Also listen for taps received while app is in foreground
    _notifSub = _startOneMinuteStreamController.stream.listen((_) {
      startSession(const Duration(minutes: 1));
    });
  }

  void disposeController() {
    _ticker?.cancel();
    _player.dispose();
    _verseRotator?.cancel();
    _notifSub?.cancel();
  }

  // Verses
  void _applyVerseMode() {
    _log('applyVerseMode: mode=' + verseMode.toString());
    _verseRotator?.cancel();
    if (verseMode == VerseMode.fixed) {
      _log('Using fixed verse (Jean 15:4-5)');
      verseRef = 'Jean 15:4-5';
      verseText =
          'Demeurez en moi, et je demeurerai en vous. Je suis le cep, vous êtes les sarments; celui qui demeure en moi et en qui je demeure porte beaucoup de fruit; sans moi vous ne pouvez rien faire.';
      notifyListeners();
    } else {
      // Try to fetch random French verses from public APIs, with local fallback
      _log('Starting random verse rotation (45s)');
      // Reflect new mode immediately in the UI
      notifyListeners();
      _fetchRandomFrVerse();
      _verseRotator = Timer.periodic(const Duration(seconds: 45), (_) {
        _log('Timer tick: fetching next random verse');
        _fetchRandomFrVerse();
      });
    }
  }

  void setVerseMode(VerseMode mode) {
    _log('setVerseMode: ' + mode.toString());
    verseMode = mode;
    // Notify immediately so Settings UI updates without waiting for network/disk
    notifyListeners();
    _savePrefs();
    _applyVerseMode();
  }

  Future<void> setAudioMode({required bool random}) async {
    audioRandom = random;
    // Notify immediately; persist in background to avoid UI lag
    notifyListeners();
    await _savePrefs();
  }

  Future<void> pickFixedAudioPath(String path) async {
    fixedAudioPath = path;
    await _savePrefs();
    notifyListeners();
  }

  void _rotateLocalFrVerse() {
    _verseIndex = (_verseIndex + 1) % frVersePool.length;
    final v = frVersePool[_verseIndex];
    verseRef = v['ref']!;
    verseText = v['text']!;
    _log('Fallback local verse → ' + verseRef);
    notifyListeners();
  }

  Future<void> _fetchRandomFrVerse() async {
    _log('fetchRandomFrVerse: start');
    // Priority unique: API.Bible (authentifié)
    try {
      final bool ok = await _tryApiBibleRandom();
      if (ok) return;
    } catch (e) {
      _log('api.bible error high-level: ' + e.toString());
    }

    // Repli local si API.Bible échoue
    _log('all endpoints failed → fallback local');
    _rotateLocalFrVerse();
  }

  Future<bool> _tryApiBibleRandom() async {
    // Resolve bible id if needed (prefer LSG/Segond)
    if (_apiBibleId == null) {
      _log('api.bible: resolving bible id (FR Segond)');
      try {
        final uri = Uri.parse('$_apiBibleBase/bibles?language=fra');
        final resp = await http.get(uri, headers: {
          'api-key': _apiBibleKey,
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 10));
        _log('api.bible /bibles status: ' + resp.statusCode.toString());
        if (resp.statusCode == 200) {
          final map = convert.json.decode(resp.body) as Map<String, dynamic>;
          final List data = (map['data'] as List?) ?? const [];
          String? picked;
          for (final d in data) {
            final m = d as Map<String, dynamic>;
            final name = (m['name'] ?? '').toString().toLowerCase();
            final abbr = (m['abbreviation'] ?? m['abbreviationLocal'] ?? '')
                .toString()
                .toLowerCase();
            if (name.contains('segond') || abbr.contains('lsg')) {
              picked = m['id']?.toString();
              break;
            }
          }
          // fallback: first FR bible if no segond found
          picked ??= data.isNotEmpty
              ? (data.first as Map<String, dynamic>)['id']?.toString()
              : null;
          if (picked != null && picked.isNotEmpty) {
            _apiBibleId = picked;
            _log('api.bible resolved bibleId=' + _apiBibleId!);
          }
        }
      } catch (e) {
        _log('api.bible resolve error: ' + e.toString());
      }
    }

    if (_apiBibleId == null) return false;

    try {
      final headers = {'api-key': _apiBibleKey, 'Accept': 'application/json'};

      // Books
      final booksUri = Uri.parse('$_apiBibleBase/bibles/${_apiBibleId}/books');
      final booksResp = await http
          .get(booksUri, headers: headers)
          .timeout(const Duration(seconds: 10));
      _log('api.bible /books status: ' + booksResp.statusCode.toString());
      if (booksResp.statusCode != 200) return false;
      final books = (convert.json.decode(booksResp.body)
          as Map<String, dynamic>)['data'] as List?;
      if (books == null || books.isEmpty) return false;
      books.shuffle();
      final Map<String, dynamic> book = books.first as Map<String, dynamic>;
      final String bookId = book['id']?.toString() ?? '';

      // Chapters
      final chaptersUri = Uri.parse(
          '$_apiBibleBase/bibles/${_apiBibleId}/books/$bookId/chapters');
      final chResp = await http
          .get(chaptersUri, headers: headers)
          .timeout(const Duration(seconds: 10));
      _log('api.bible /chapters status: ' + chResp.statusCode.toString());
      if (chResp.statusCode != 200) return false;
      final chapters = (convert.json.decode(chResp.body)
          as Map<String, dynamic>)['data'] as List?;
      if (chapters == null || chapters.isEmpty) return false;
      chapters.shuffle();
      final Map<String, dynamic> chapter =
          chapters.first as Map<String, dynamic>;
      final String chapterId = chapter['id']?.toString() ?? '';

      // Verses
      final versesUri = Uri.parse(
          '$_apiBibleBase/bibles/${_apiBibleId}/chapters/$chapterId/verses');
      final vResp = await http
          .get(versesUri, headers: headers)
          .timeout(const Duration(seconds: 10));
      _log('api.bible /verses status: ' + vResp.statusCode.toString());
      if (vResp.statusCode != 200) return false;
      final verses = (convert.json.decode(vResp.body)
          as Map<String, dynamic>)['data'] as List?;
      if (verses == null || verses.isEmpty) return false;
      verses.shuffle();
      final Map<String, dynamic> verse = verses.first as Map<String, dynamic>;
      final String verseId = verse['id']?.toString() ?? '';

      // Verse content (plain text)
      final verseUri = Uri.parse(
          '$_apiBibleBase/bibles/${_apiBibleId}/verses/$verseId?content-type=text');
      final cResp = await http
          .get(verseUri, headers: headers)
          .timeout(const Duration(seconds: 10));
      _log('api.bible /verse status: ' + cResp.statusCode.toString());
      if (cResp.statusCode != 200 || cResp.body.isEmpty) return false;
      final Map<String, dynamic> vData =
          convert.json.decode(cResp.body) as Map<String, dynamic>;
      final Map<String, dynamic>? d = vData['data'] as Map<String, dynamic>?;
      final String? content = d == null
          ? null
          : (_stringOrNull(d['content']) ?? _stringOrNull(d['text']));
      final String? reference =
          d == null ? null : _stringOrNull(d['reference']);
      if (content != null &&
          content.trim().isNotEmpty &&
          reference != null &&
          reference.trim().isNotEmpty) {
        verseRef = reference.trim();
        verseText = content.trim();
        _log('api.bible success → ' + verseRef);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _log('api.bible error: ' + e.toString());
    }

    return false;
  }

  // Removed legacy parsers now that we exclusively use API.Bible

  String? _stringOrNull(dynamic v) => v is String ? v : v?.toString();

  // Timer + audio
  void startSession(Duration d) {
    isRunning = true;
    total = d;
    remaining = d;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (remaining.inSeconds <= 1) {
        // End of session: reset to initial state
        remaining = Duration.zero;
        total = Duration.zero;
        isRunning = false;
        await _player.stop();
        isAudioPlaying = false;
        t.cancel();
        notifyListeners();
      } else {
        remaining = Duration(seconds: remaining.inSeconds - 1);
        notifyListeners();
      }
    });
    _startMusic();
    notifyListeners();
  }

  Future<void> toggleAudio() async {
    if (isAudioPlaying) {
      await _player.pause();
      isAudioPlaying = false;
    } else {
      if (_currentTrackPath == null) {
        // No track loaded yet → start random/fixed according to settings
        await _startMusic();
      } else {
        await _player.resume();
        isAudioPlaying = true;
      }
    }
    notifyListeners();
  }

  Future<void> nextTrack() async {
    final files = await getLocalAudioFiles();
    if (files.isEmpty) return;
    if (_currentTrackPath == null) {
      await playFile(files.first);
      return;
    }
    int idx = files.indexWhere((f) => f.path == _currentTrackPath);
    idx = (idx + 1) % files.length;
    await playFile(files[idx]);
  }

  Future<void> previousTrack() async {
    final files = await getLocalAudioFiles();
    if (files.isEmpty) return;
    if (_currentTrackPath == null) {
      await playFile(files.first);
      return;
    }
    int idx = files.indexWhere((f) => f.path == _currentTrackPath);
    idx = (idx - 1) < 0 ? files.length - 1 : (idx - 1);
    await playFile(files[idx]);
  }

  Future<void> seekBy(Duration delta) async {
    try {
      final pos = await _player.getCurrentPosition();
      final dur = await _player.getDuration();
      final current = pos ?? Duration.zero;
      final totalDur = dur ?? Duration.zero;
      Duration target = current + delta;
      if (target < Duration.zero) target = Duration.zero;
      if (totalDur > Duration.zero && target > totalDur) target = totalDur;
      await _player.seek(target);
    } catch (_) {}
  }

  Future<void> toggleMute() async {
    if (!isAudioPlaying) {
      // Do nothing if no audio is currently playing
      return;
    }
    isMuted = !isMuted;
    await _player.setVolume(isMuted ? 0.0 : _defaultVolume);
    notifyListeners();
  }

  Future<void> _startMusic() async {
    try {
      File? picked;
      if (!audioRandom &&
          fixedAudioPath != null &&
          await File(fixedAudioPath!).exists()) {
        picked = File(fixedAudioPath!);
      } else {
        final files = await _ensureLocalAudioFiles();
        if (files.isEmpty) return;
        files.shuffle();
        picked = files.first;
      }
      await _player.stop();
      await _player.play(DeviceFileSource(picked.path),
          volume: isMuted ? 0.0 : _defaultVolume);
      isAudioPlaying = true;
      currentTrackName = _displayNameFromPath(picked.path);
      _currentTrackPath = picked.path;
    } catch (_) {}
  }

  Future<List<File>> getLocalAudioFiles() async {
    final Directory appDir = await getApplicationSupportDirectory();
    final Directory audioDir = Directory('${appDir.path}/audio');
    if (!await audioDir.exists()) {
      return [];
    }
    final List<FileSystemEntity> entries = await audioDir.list().toList();
    final List<File> files = entries
        .whereType<File>()
        .where((f) =>
            f.path.toLowerCase().endsWith('.mp3') ||
            f.path.toLowerCase().endsWith('.m4a') ||
            f.path.toLowerCase().endsWith('.aac'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<bool> deleteLocalAudioFileAtPath(String path) async {
    try {
      final File target = File(path);
      if (!await target.exists()) return false;
      if (_currentTrackPath == path) {
        await _player.stop();
        isAudioPlaying = false;
        currentTrackName = null;
        _currentTrackPath = null;
      }
      await target.delete();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> importFromDevicePaths(List<String> sourcePaths) async {
    int imported = 0;
    final Directory appDir = await getApplicationSupportDirectory();
    final Directory audioDir = Directory('${appDir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    for (final path in sourcePaths) {
      try {
        final File src = File(path);
        if (!await src.exists()) continue;
        final String name = src.path.split('/').last;
        final int dot = name.lastIndexOf('.');
        final String base = dot > 0 ? name.substring(0, dot) : name;
        final String ext = dot > 0 ? name.substring(dot) : '';
        String candidate = '${audioDir.path}/$name';
        int i = 1;
        while (await File(candidate).exists()) {
          candidate = '${audioDir.path}/$base ($i)$ext';
          i++;
        }
        await src.copy(candidate);
        imported++;
      } catch (_) {}
    }
    return imported;
  }

  Future<String?> importSingleAudioFile(String sourcePath) async {
    try {
      final Directory appDir = await getApplicationSupportDirectory();
      final Directory audioDir = Directory('${appDir.path}/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      final File src = File(sourcePath);
      if (!await src.exists()) return null;
      final String name = src.path.split('/').last;
      final int dot = name.lastIndexOf('.');
      final String base = dot > 0 ? name.substring(0, dot) : name;
      final String ext = dot > 0 ? name.substring(dot) : '';
      String candidate = '${audioDir.path}/$name';
      int i = 1;
      while (await File(candidate).exists()) {
        candidate = '${audioDir.path}/$base ($i)$ext';
        i++;
      }
      final File dest = File(candidate);
      await src.copy(dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> playFile(File f) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(DeviceFileSource(f.path),
          volume: isMuted ? 0.0 : _defaultVolume);
      isAudioPlaying = true;
      currentTrackName = _displayNameFromPath(f.path);
      _currentTrackPath = f.path;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _playNextTrack() async {
    final files = await getLocalAudioFiles();
    if (files.isEmpty) {
      isAudioPlaying = false;
      notifyListeners();
      return;
    }
    // pick a different track if possible
    File next = files.first;
    if (_currentTrackPath != null && files.length > 1) {
      files.shuffle();
      next = files.firstWhere(
        (f) => f.path != _currentTrackPath,
        orElse: () => files.first,
      );
    }
    await playFile(next);
  }

  Future<void> _setupAudio() async {
    try {
      // Configure audio for background playback on both platforms
      await AudioPlayer.global.setAudioContext(
        const AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: [
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowAirPlay,
              AVAudioSessionOptions.allowBluetooth,
            ],
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<List<File>> _ensureLocalAudioFiles() async {
    final Directory appDir = await getApplicationSupportDirectory();
    final Directory audioDir = Directory('${appDir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    // 1) Copy bundled assets from assets/audio into local dir if not present
    try {
      final String manifestJson =
          await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest =
          convert.json.decode(manifestJson) as Map<String, dynamic>;
      final List<String> assetAudioPaths = manifest.keys
          .where((k) =>
              k.startsWith('assets/audio/') &&
              (k.toLowerCase().endsWith('.mp3') ||
                  k.toLowerCase().endsWith('.m4a') ||
                  k.toLowerCase().endsWith('.aac')))
          .toList();
      for (final String assetPath in assetAudioPaths) {
        final String fileName = assetPath.split('/').last;
        final File dest = File('${audioDir.path}/$fileName');
        if (!await dest.exists()) {
          try {
            final byteData = await rootBundle.load(assetPath);
            await dest.writeAsBytes(byteData.buffer.asUint8List());
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 2) Download remote files if missing
    final List<File> downloaded = [];
    for (final url in _audioUrls) {
      final String fileName = Uri.parse(url).pathSegments.last;
      final File f = File('${audioDir.path}/$fileName');
      if (!await f.exists()) {
        try {
          final resp = await http.get(Uri.parse(url));
          if (resp.statusCode == 200) {
            await f.writeAsBytes(resp.bodyBytes);
          }
        } catch (_) {}
      }
      if (await f.exists()) downloaded.add(f);
    }
    // 3) Return all local files that match audio extensions
    final List<FileSystemEntity> entries = await audioDir.list().toList();
    final List<File> all = entries
        .whereType<File>()
        .where((f) =>
            f.path.toLowerCase().endsWith('.mp3') ||
            f.path.toLowerCase().endsWith('.m4a') ||
            f.path.toLowerCase().endsWith('.aac'))
        .toList();
    return all;
  }

  String _displayNameFromPath(String path) {
    final String name = path.split('/').last;
    return name.replaceAll(
        RegExp(r'\.(mp3|m4a|aac)$', caseSensitive: false), '');
  }

  // Notifications
  Future<void> _initNotifications() async {
    await fln
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Android 13+ runtime permission for notifications
    final androidImpl = fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      try {
        // Use dynamic call to avoid compile-time errors when API not present
        await (androidImpl as dynamic).requestPermission?.call();
      } catch (_) {
        // Ignore if not supported
      }
    }

    await scheduleTwinHourNotifications();
  }

  // Preferences
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String mode = prefs.getString('verse_mode') ?? 'fixed';
    verseMode = mode == 'random' ? VerseMode.random : VerseMode.fixed;
    audioRandom = prefs.getBool('audio_random') ?? true;
    fixedAudioPath = prefs.getString('fixed_audio_path');
    final int? customSec = prefs.getInt('custom_quick_duration_sec');
    if (customSec != null && customSec > 0) {
      customQuickDuration = Duration(seconds: customSec);
    }
    final int? selectedQuickSec = prefs.getInt('selected_quick_duration_sec');
    if (selectedQuickSec != null && selectedQuickSec > 0) {
      selectedQuickDuration = Duration(seconds: selectedQuickSec);
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'verse_mode', verseMode == VerseMode.random ? 'random' : 'fixed');
    await prefs.setBool('audio_random', audioRandom);
    if (fixedAudioPath != null) {
      await prefs.setString('fixed_audio_path', fixedAudioPath!);
    } else {
      await prefs.remove('fixed_audio_path');
    }
    await prefs.setInt(
        'custom_quick_duration_sec', customQuickDuration?.inSeconds ?? 0);
    await prefs.setInt(
        'selected_quick_duration_sec', selectedQuickDuration.inSeconds);
  }

  Future<void> setCustomQuickDuration(Duration? d) async {
    customQuickDuration = d;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setSelectedQuickDuration(Duration d) async {
    selectedQuickDuration = d;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> scheduleTwinHourNotifications() async {
    await fln.cancelAll();
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'twin_hours_channel',
      'Twin Hours',
      channelDescription:
          'Notifications pour heures jumelles (00:00, 01:01, ..., 23:23)',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_launcher',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'start_1m_action',
          'Prier 1m',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'twin_actions',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    const NotificationDetails details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final DateTime now = DateTime.now();
    for (int h = 0; h < 24; h++) {
      final DateTime today = DateTime(now.year, now.month, now.day, h, h);
      DateTime scheduled =
          today.isAfter(now) ? today : today.add(const Duration(days: 1));
      final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduled, tz.local);
      await fln.zonedSchedule(
        1000 + h,
        "Rien qu'une minute !",
        "Mon enfant pourrais-tu me donner une minute de ton temps ?",
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'start_1m',
      );
    }
  }

  Future<void> sendTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'twin_hours_channel',
      'Twin Hours',
      channelDescription:
          'Notifications pour heures jumelles (00:00, 01:01, ..., 23:23)',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_launcher',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'start_1m_action',
          'Prier 1m',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'twin_actions',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    const NotificationDetails details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await fln.show(
      9999,
      "Rien qu'une minute !",
      "Mon enfant pourrais-tu me donner une minute de ton temps ?",
      details,
      payload: 'start_1m',
    );
  }
}
