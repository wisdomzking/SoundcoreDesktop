import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ai/moss_stt.dart';
import '../ai/soniox_stt.dart';
import '../ai/speech_provider.dart';
import '../ai/stt_types.dart';
import '../audio/ogg_opus.dart';

enum JobStatus { idle, preparing, uploading, processing, done, failed }

/// One imported audio file and its transcription state.
class TranscriptionJob {
  TranscriptionJob({
    required this.id,
    required this.path,
    required this.fileName,
    this.status = JobStatus.idle,
    this.progress,
    this.text,
    this.language,
    this.error,
    this.duration,
  });

  final String id;
  final String path;
  final String fileName;
  JobStatus status;
  String? progress;
  String? text;
  String? language;
  String? error;
  Duration? duration;

  bool get isDone => status == JobStatus.done && text != null;
  bool get isBusy => status == JobStatus.preparing ||
      status == JobStatus.uploading ||
      status == JobStatus.processing;

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'fileName': fileName,
        'status': status.name,
        'text': text,
        'language': language,
        'error': error,
      };

  factory TranscriptionJob.fromJson(Map<String, dynamic> j) => TranscriptionJob(
        id: j['id'] as String,
        path: j['path'] as String,
        fileName: j['fileName'] as String,
        status: JobStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => JobStatus.idle,
        ),
        text: j['text'] as String?,
        language: j['language'] as String?,
        error: j['error'] as String?,
      );
}

class DesktopController extends ChangeNotifier {
  DesktopController();

  final List<TranscriptionJob> _jobs = [];
  List<TranscriptionJob> get jobs => List.unmodifiable(_jobs);

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  String? _playingJobId;
  String? get playingJobId => _playingJobId;

  SttProvider _provider = SttProvider.moss;
  SttProvider get provider => _provider;

  String _language = 'auto';
  String get language => _language;

  String? _sonioxKey;
  String? _mossKey;
  String? get sonioxKey => _sonioxKey;
  String? get mossKey => _mossKey;

  String? _lastError;
  String? get lastError => _lastError;

  late final SonioxSttService _soniox = SonioxSttService();
  late final MossSttService _moss = MossSttService();

  static const _indexFile = 'transcription_index.json';
  Directory? _workDir;

  Future<void> initialize() async {
    final docs = await getApplicationDocumentsDirectory();
    _workDir = Directory(p.join(docs.path, 'SoundcoreDesktop'));
    if (!_workDir!.existsSync()) _workDir!.createSync(recursive: true);

    await _loadSettings();
    await _loadIndex();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playingJobId = null;
        notifyListeners();
      }
    });
  }

  Future<File> _settingsFile() async =>
      File(p.join(_workDir!.path, 'settings.json'));

  Future<void> _loadSettings() async {
    try {
      final f = await _settingsFile();
      if (!f.existsSync()) return;
      final map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      _sonioxKey = map['sonioxKey'] as String?;
      _mossKey = map['mossKey'] as String?;
      final pName = map['provider'] as String?;
      if (pName != null) {
        _provider = SttProvider.values.firstWhere(
          (v) => v.name == pName,
          orElse: () => SttProvider.moss,
        );
      }
      _language = map['language'] as String? ?? 'auto';
    } catch (e) {
      debugPrint('[Settings] load failed: $e');
    }
  }

  Future<void> saveSettings({
    SttProvider? provider,
    String? language,
    String? sonioxKey,
    String? mossKey,
  }) async {
    if (provider != null) _provider = provider;
    if (language != null) _language = language;
    if (sonioxKey != null) _sonioxKey = sonioxKey.trim().isEmpty ? null : sonioxKey.trim();
    if (mossKey != null) _mossKey = mossKey.trim().isEmpty ? null : mossKey.trim();
    final map = {
      'provider': _provider.name,
      'language': _language,
      'sonioxKey': _sonioxKey,
      'mossKey': _mossKey,
    };
    try {
      final f = await _settingsFile();
      f.writeAsStringSync(jsonEncode(map));
    } catch (e) {
      debugPrint('[Settings] save failed: $e');
    }
    notifyListeners();
  }

  Future<File> _indexFile() async => File(p.join(_workDir!.path, _indexFile));

  Future<void> _loadIndex() async {
    try {
      final f = await _indexFile();
      if (!f.existsSync()) return;
      final list = jsonDecode(f.readAsStringSync()) as List<dynamic>;
      _jobs.addAll(
        list
            .whereType<Map<String, dynamic>>()
            .map(TranscriptionJob.fromJson)
            .where((j) => File(j.path).existsSync()),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[Index] load failed: $e');
    }
  }

  Future<void> _saveIndex() async {
    try {
      final f = await _indexFile();
      f.writeAsStringSync(
        jsonEncode(_jobs.map((j) => j.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[Index] save failed: $e');
    }
  }

  /// Copy imported files into app storage so they survive app moves.
  Future<void> importFiles(List<File> sources) async {
    for (final src in sources) {
      final name = p.basename(src.path);
      final dest = File(p.join(_workDir!.path, '${DateTime.now().microsecondsSinceEpoch}_$name'));
      await src.copy(dest.path);
      final job = TranscriptionJob(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        path: dest.path,
        fileName: name,
      );
      _jobs.insert(0, job);
    }
    await _saveIndex();
    notifyListeners();
  }

  Future<void> removeJob(String id) async {
    final idx = _jobs.indexWhere((j) => j.id == id);
    if (idx < 0) return;
    final job = _jobs[idx];
    if (_playingJobId == id) await stopPlayback();
    try {
      final f = File(job.path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    _jobs.removeAt(idx);
    await _saveIndex();
    notifyListeners();
  }

  bool get canTranscribe => _provider == SttProvider.moss ? _mossKey != null : _sonioxKey != null;

  Future<void> transcribe(TranscriptionJob job) async {
    if (!canTranscribe) {
      job.status = JobStatus.failed;
      job.error = '请先在设置中配置 ${_provider.label} API Key';
      notifyListeners();
      return;
    }

    job.status = JobStatus.preparing;
    job.progress = '准备音频…';
    job.error = null;
    notifyListeners();

    try {
      SttResult result;
      if (_provider == SttProvider.moss) {
        _moss.apiKeyOverride = _mossKey;
        result = await _moss.transcribeFile(
          job.path,
          key: _mossKey!,
          language: _language == 'auto' ? null : _language,
          onProgress: (prog) => _updateProgress(job, prog),
        );
      } else {
        _soniox.apiKeyOverride = _sonioxKey;
        result = await _soniox.transcribePath(
          job.path,
          language: _language,
          onProgress: (prog) => _updateProgress(job, prog),
        );
      }
      job.text = result.text;
      job.language = result.language ?? _language;
      job.status = JobStatus.done;
      job.progress = null;
    } catch (e) {
      job.status = JobStatus.failed;
      job.error = '$e';
      job.progress = null;
    }
    await _saveIndex();
    notifyListeners();
  }

  void _updateProgress(TranscriptionJob job, SttFileProgress prog) {
    switch (prog.stage) {
      case SttFileStage.preparing:
        job.status = JobStatus.preparing;
        job.progress = '准备音频…';
      case SttFileStage.uploading:
        job.status = JobStatus.uploading;
        final pct = prog.fraction;
        job.progress = pct != null
            ? '上传中 ${(pct * 100).toInt()}%'
            : '上传中…';
      case SttFileStage.queued:
        job.status = JobStatus.processing;
        job.progress = '排队中…';
      case SttFileStage.processing:
        job.status = JobStatus.processing;
        job.progress = 'AI 转写中…';
      case SttFileStage.fetching:
        job.status = JobStatus.processing;
        job.progress = '获取结果…';
    }
    notifyListeners();
  }

  Future<void> play(TranscriptionJob job) async {
    try {
      // Raw .opus needs Ogg muxing first (pure Dart).
      String playable = job.path;
      if (job.path.endsWith('.opus')) {
        playable = await OggOpus.ensurePlayable(job.path);
      }
      await _player.setFilePath(playable);
      _playingJobId = job.id;
      await _player.play();
    } catch (e) {
      _lastError = '播放失败：$e';
    }
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    _playingJobId = null;
    notifyListeners();
  }

  Future<void> pausePlayback() async {
    await _player.pause();
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    _soniox.dispose();
    _moss.dispose();
    super.dispose();
  }
}
