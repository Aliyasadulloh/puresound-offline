import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

class WavData {
  final int sampleRate;
  final Float32List samples;
  WavData(this.sampleRate, this.samples);
}

class WavUtils {
  static Future<WavData> readWav(String path) async {
    final bytes = await File(path).readAsBytes();
    final bd = ByteData.sublistView(bytes);

    final sampleRate = bd.getUint32(24, Endian.little);

    int offset = 12;
    int dataSize = 0;
    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bd.getUint32(offset + 4, Endian.little);
      if (chunkId == 'data') {
        offset += 8;
        dataSize = chunkSize;
        break;
      }
      offset += 8 + chunkSize;
    }

    final numSamples = dataSize ~/ 2;
    final samples = Float32List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final pcm = bd.getInt16(offset + i * 2, Endian.little);
      samples[i] = pcm / 32768.0;
    }
    return WavData(sampleRate, samples);
  }

  static Future<void> writeWav(
    String path,
    Float32List samples,
    int sampleRate,
  ) async {
    final dataSize = samples.length * 2;
    final buffer = Uint8List(44 + dataSize);
    final bd = ByteData.sublistView(buffer);

    void writeAscii(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        buffer[offset + i] = s.codeUnitAt(i);
      }
    }

    writeAscii(0, 'RIFF');
    bd.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, 1, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    bd.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      bd.setInt16(44 + i * 2, (clamped * 32767.0).round(), Endian.little);
    }

    await File(path).writeAsBytes(buffer, flush: true);
  }

  static Float32List hannWindow(int length) {
    final win = Float32List(length);
    for (int i = 0; i < length; i++) {
      win[i] = 0.5 * (1.0 - math.cos((2.0 * math.pi * i) / (length - 1)));
    }
    return win;
  }
}
