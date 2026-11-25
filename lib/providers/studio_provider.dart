import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import '../models/audio_models.dart';
import '../services/ffmpeg_service.dart';
import '../services/model_manager.dart';
import '../services/onnx_denoiser.dart';

final studioProvider = StateNotifierProvider<StudioNotifier, StudioState>((ref) {
  return StudioNotifier();
});

class StudioNotifier extends StateNotifier<StudioState> {
  final _modelManager = ModelManager();
  final _denoiser = OnnxDenoiserService();
  final _ffmpeg = FfmpegService();
  final _recorder = AudioRecorder();
  final AudioPlayer player = AudioPlayer();

  String? _extractedOrigWav;
  String? _rawDenoisedWav;

  StudioNotifier() : super(const StudioState()) {
    _bootstrapModel();
    player.playerStateStream.listen((ps) {
      state = state.copyWith(isPlaying: ps.playing);
    });
  }

  Future<void> _bootstrapModel() async {
    try {
      state = state.copyWith(statusText: 'AI modeli tekshirilmoqda...');
      final file = await _modelManager.ensureModel(
        onProgress: (prog) => state = state.copyWith(
          modelDownloadProgress: prog,
          statusText: 'AI modeli yuklanmoqda: ${(prog * 100).toInt()}%',
        ),
      );
      await _denoiser.init(file.path);
      state = state.copyWith(
        isModelReady: true,
        statusText: 'Offline AI tayyor',
      );
    } catch (e) {
      state = state.copyWith(statusText: 'Model xatosi: $e');
    }
  }

  void setInputMode(InputMode mode) {
    player.stop();
    state = state.copyWith(inputMode: mode);
  }

  void setPreset(DenoisePreset preset) {
    state = state.copyWith(preset: preset);
    if (_rawDenoisedWav != null) {
      _rebuildMixAndOutput();
    }
  }

  void setWetDry(double value) {
    state = state.copyWith(wetDryMix: value);
  }

  Future<void> commitWetDry() async {
    if (_rawDenoisedWav != null) {
      await _rebuildMixAndOutput();
    }
  }

  Future<void> toggleRecording() async {
    if (state.isRecording) {
      final path = await _recorder.stop();
      state = state.copyWith(isRecording: false);
      if (path != null) {
        await processInputFile(path);
      }
      return;
    }

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      state = state.copyWith(statusText: 'Mikrofon ruxsati berilmadi');
      return;
    }

    final dir = await getTemporaryDirectory();
    final recPath = p.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.wav');
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: recPath,
    );
    state = state.copyWith(
      isRecording: true,
      statusText: 'Yozib olinmoqda...',
    );
  }

  Future<void> pickFile() async {
    final isVideo = state.inputMode == InputMode.video;
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: isVideo
          ? ['mp4', 'mov', 'mkv']
          : ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
    );
    if (res != null && res.files.single.path != null) {
      await processInputFile(res.files.single.path!);
    }
  }

  Future<void> processInputFile(String inputPath) async {
    if (!state.isModelReady) return;
    await player.stop();

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _extractedOrigWav = p.join(dir.path, 'orig_$ts.wav');
    _rawDenoisedWav = p.join(dir.path, 'ai_$ts.wav');

    state = state.copyWith(
      originalPath: inputPath,
      isProcessing: true,
      processProgress: 0.05,
      statusText: 'Audio ajratilmoqda (FFmpeg)...',
    );

    try {
      await _ffmpeg.extractPcm16k(inputPath, _extractedOrigWav!);

      state = state.copyWith(
        processProgress: 0.2,
        statusText: 'ONNX AI shovqinni tozalamoqda...',
      );

      await _denoiser.denoiseWav(
        inputWavPath: _extractedOrigWav!,
        outputWavPath: _rawDenoisedWav!,
        onProgress: (prog) {
          state = state.copyWith(
            processProgress: 0.2 + (prog * 0.6),
            statusText: 'AI tozalash: ${(prog * 100).toInt()}%',
          );
        },
      );

      await _rebuildMixAndOutput();
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        statusText: 'Xatolik: $e',
      );
    }
  }

  Future<void> _rebuildMixAndOutput() async {
    if (_extractedOrigWav == null || _rawDenoisedWav == null || state.originalPath == null) {
      return;
    }
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final mixedWav = p.join(dir.path, 'mixed_$ts.wav');

    state = state.copyWith(
      isProcessing: true,
      processProgress: 0.85,
      statusText: 'EQ, Loudness va Mix qo‘llanmoqda...',
    );

    await _ffmpeg.applyPresetAndMix(
      originalWavPath: _extractedOrigWav!,
      denoisedWavPath: _rawDenoisedWav!,
      outputAudioPath: mixedWav,
      preset: state.preset,
      wetDryMix: state.wetDryMix,
    );

    String finalOut = mixedWav;
    if (state.inputMode == InputMode.video) {
      state = state.copyWith(
        processProgress: 0.92,
        statusText: 'Video sifatini yo‘qotmasdan yig‘ilmoqda...',
      );
      final outVideo = p.join(dir.path, 'puresound_$ts.mp4');
      await _ffmpeg.remuxAudioToVideo(
        originalVideoPath: state.originalPath!,
        cleanedAudioPath: mixedWav,
        outputVideoPath: outVideo,
      );
      finalOut = outVideo;
    }

    state = state.copyWith(
      isProcessing: false,
      processProgress: 1.0,
      cleanedPath: mixedWav,
      finalMixedPath: finalOut,
      statusText: 'Tayyor! Solishtirib eshiting.',
    );

    if (state.inputMode != InputMode.video) {
      await _loadAudioForPlayback(state.playCleaned);
    }
  }

  Future<void> toggleBeforeAfter(bool playCleaned) async {
    final pos = player.position;
    final wasPlaying = player.playing;
    state = state.copyWith(playCleaned: playCleaned);

    if (state.inputMode != InputMode.video) {
      await _loadAudioForPlayback(playCleaned, seekTo: pos, autoPlay: wasPlaying);
    }
  }

  Future<void> _loadAudioForPlayback(
    bool cleaned, {
    Duration seekTo = Duration.zero,
    bool autoPlay = false,
  }) async {
    final target = cleaned ? state.cleanedPath : _extractedOrigWav;
    if (target == null) return;
    await player.setFilePath(target);
    await player.seek(seekTo);
    if (autoPlay) await player.play();
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> exportAndShare({bool saveToGallery = false}) async {
    final path = state.finalMixedPath;
    if (path == null) return;

    if (saveToGallery && state.inputMode == InputMode.video) {
      await Gal.putVideo(path);
      state = state.copyWith(statusText: 'Galereyaga saqlandi!');
      return;
    }

    String exportPath = path;
    if (state.inputMode != InputMode.video && path.endsWith('.wav')) {
      final dir = await getTemporaryDirectory();
      final mp3Path = p.join(dir.path, 'PureSound_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await _ffmpeg.convertToMp3(path, mp3Path);
      exportPath = mp3Path;
    }

    await Share.shareXFiles([XFile(exportPath)], text: 'PureSound Offline orqali tozalandi');
  }

  @override
  void dispose() {
    player.dispose();
    _recorder.dispose();
    _denoiser.dispose();
    super.dispose();
  }
}
