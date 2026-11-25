import 'dart:io';
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import 'wav_utils.dart';

class OnnxDenoiserService {
  OrtSession? _session;

  Future<void> init(String modelPath) async {
    if (_session != null) return;
    OrtEnv.instance.init();
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(4)
      ..setInterOpNumThreads(1);

    final modelBytes = await File(modelPath).readAsBytes();
    _session = OrtSession.fromBuffer(modelBytes, options);
  }

  Future<void> denoiseWav({
    required String inputWavPath,
    required String outputWavPath,
    required void Function(double progress) onProgress,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError('ONNX session yuklanmagan!');
    }

    final wav = await WavUtils.readWav(inputWavPath);
    final input = wav.samples;
    final totalSamples = input.length;

    const int frameSize = 32000;
    const int hopSize = 16000;
    final window = WavUtils.hannWindow(frameSize);

    final output = Float32List(totalSamples);
    final norm = Float32List(totalSamples);

    final inputName = session.inputNames.first;
    final runOptions = OrtRunOptions();

    int totalFrames = ((totalSamples - 1) ~/ hopSize) + 1;
    int frameIdx = 0;

    for (int start = 0; start < totalSamples; start += hopSize) {
      final chunk = Float32List(frameSize);
      final remaining = totalSamples - start;
      final copyLen = remaining < frameSize ? remaining : frameSize;

      for (int i = 0; i < copyLen; i++) {
        chunk[i] = input[start + i];
      }

      final inputTensor = OrtValueTensor.createTensorWithDataList(
        chunk,
        [1, 1, frameSize],
      );

      final outputs = session.run(runOptions, {inputName: inputTensor});
      inputTensor.release();

      final rawOut = outputs.first?.value;
      final denoisedChunk = _flattenOutput(rawOut, frameSize);

      for (final o in outputs) {
        o?.release();
      }

      for (int i = 0; i < copyLen; i++) {
        final w = window[i];
        output[start + i] += denoisedChunk[i] * w;
        norm[start + i] += w;
      }

      frameIdx++;
      onProgress((frameIdx / totalFrames).clamp(0.0, 1.0));
    }

    runOptions.release();

    for (int i = 0; i < totalSamples; i++) {
      if (norm[i] > 1e-6) {
        output[i] /= norm[i];
      }
    }

    await WavUtils.writeWav(outputWavPath, output, wav.sampleRate);
  }

  Float32List _flattenOutput(dynamic raw, int expectedLen) {
    final result = Float32List(expectedLen);
    int idx = 0;

    void extract(dynamic node) {
      if (idx >= expectedLen) return;
      if (node is double) {
        result[idx++] = node;
      } else if (node is List) {
        for (final item in node) {
          extract(item);
        }
      }
    }

    extract(raw);
    return result;
  }

  void dispose() {
    _session?.release();
    _session = null;
    OrtEnv.instance.release();
  }
}
