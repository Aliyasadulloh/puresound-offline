import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ModelManager {
  static const String generalModelAsset = 'assets/models/sh.rnnn';
  static const String voiceModelAsset = 'assets/models/bd.rnnn';

  Future> prepareBundledModels() async {
    final dir = await getApplicationDocumentsDirectory();
    final generalPath =
        await _copyAsset(generalModelAsset, p.join(dir.path, 'sh.rnnn'));
    final voicePath =
        await _copyAsset(voiceModelAsset, p.join(dir.path, 'bd.rnnn'));
    return {
      'general': generalPath,
      'voice': voicePath,
    };
  }

  Future<String> _copyAsset(String assetPath, String targetPath) async {
    final file = File(targetPath);
    if (!file.existsSync() || file.lengthSync() < 1000) {
      final data = await rootBundle.load(assetPath);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }
}
