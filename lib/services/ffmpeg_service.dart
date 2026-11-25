import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../models/audio_models.dart';

class FfmpegService {
  Future<void> _exec(String command) async {
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg xatosi: $logs');
    }
  }

  Future<void> extractPcm16k(String inputPath, String outputWavPath) async {
    await _exec(
      '-y -i "$inputPath" -vn -acodec pcm_s16le -ar 48000 -ac 1 "$outputWavPath"',
    );
  }

  /// 100% Oflayn lokal shovqin tozalash (internet va tashqi model shart emas)
  Future<void> denoiseAudioOffline({
    required String inputWavPath,
    required String outputWavPath,
    required DenoisePreset preset,
  }) async {
    String denoiseFilter;
    switch (preset) {
      case DenoisePreset.light:
        denoiseFilter = 'highpass=f=70,afftdn=nr=12:nf=-30:tn=1';
        break;
      case DenoisePreset.strong:
        denoiseFilter =
            'highpass=f=100,lowpass=f=12000,afftdn=nr=22:nf=-25:tn=1,anlmdn=s=0.0005:p=0.002:r=0.006:m=15';
        break;
      case DenoisePreset.studio:
        denoiseFilter =
            'highpass=f=85,afftdn=nr=18:nf=-28:tn=1,anlmdn=s=0.0003:p=0.002:r=0.006:m=12';
        break;
    }

    await _exec(
      '-y -i "$inputWavPath" -af "$denoiseFilter" -acodec pcm_s16le -ar 48000 -ac 1 "$outputWavPath"',
    );
  }

  Future<void> applyPresetAndMix({
    required String originalWavPath,
    required String denoisedWavPath,
    required String outputAudioPath,
    required DenoisePreset preset,
    required double wetDryMix,
  }) async {
    final wet = wetDryMix.clamp(0.0, 1.0);
    final dry = (1.0 - wet).clamp(0.0, 1.0);

    String postFilter;
    switch (preset) {
      case DenoisePreset.light:
        postFilter = 'highpass=f=70,lowpass=f=15000';
        break;
      case DenoisePreset.strong:
        postFilter = 'highpass=f=95,lowpass=f=12500';
        break;
      case DenoisePreset.studio:
        postFilter =
            'highpass=f=85,equalizer=f=250:t=q:w=1.2:g=-2,equalizer=f=3500:t=q:w=1.0:g=3,loudnorm=I=-16:TP=-1.5:LRA=11';
        break;
    }

    final filterComplex =
        '[0:a]volume=$dry[a0];[1:a]volume=$wet[a1];[a0][a1]amix=inputs=2:duration=first:normalize=0,$postFilter[out]';

    await _exec(
      '-y -i "$originalWavPath" -i "$denoisedWavPath" '
      '-filter_complex "$filterComplex" -map "[out]" -ar 48000 -ac 1 "$outputAudioPath"',
    );
  }

  Future<void> remuxAudioToVideo({
    required String originalVideoPath,
    required String cleanedAudioPath,
    required String outputVideoPath,
  }) async {
    await _exec(
      '-y -i "$originalVideoPath" -i "$cleanedAudioPath" '
      '-c:v copy -c:a aac -b:a 192k -map 0:v:0 -map 1:a:0 -shortest "$outputVideoPath"',
    );
  }

  Future<void> convertToMp3(String inputWav, String outputMp3) async {
    await _exec('-y -i "$inputWav" -codec:a libmp3lame -b:a 192k "$outputMp3"');
  }
}
