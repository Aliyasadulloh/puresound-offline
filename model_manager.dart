import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ModelManager {
  static const String modelFileName = 'dns48_denoiser_int8.onnx';
  static const String modelDownloadUrl =
      'https://huggingface.co/onnx-community/denoiser-dns48/resolve/main/onnx/model_quantized.onnx';

  Future<File> getModelFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, modelFileName));
  }

  Future<bool> isModelDownloaded() async {
    final file = await getModelFile();
    return file.existsSync() && file.lengthSync() > 100000;
  }

  Future<File> ensureModel({
    required void Function(double progress) onProgress,
  }) async {
    final file = await getModelFile();
    if (await isModelDownloaded()) {
      onProgress(1.0);
      return file;
    }

    final dio = Dio();
    final tempPath = '${file.path}.tmp';
    await dio.download(
      modelDownloadUrl,
      tempPath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress(received / total);
        }
      },
    );

    final tempFile = File(tempPath);
    await tempFile.rename(file.path);
    onProgress(1.0);
    return file;
  }
}
