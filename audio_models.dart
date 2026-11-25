enum InputMode { recorder, audio, video }

enum DenoisePreset {
  light('Light', 'Ovozni tabiiy saqlash'),
  strong('Strong', 'Ko‘cha va shamol shovqini'),
  studio('Studio Vocal', 'AI + EQ + Loudness');

  final String title;
  final String subtitle;
  const DenoisePreset(this.title, this.subtitle);
}

class StudioState {
  final InputMode inputMode;
  final DenoisePreset preset;
  final double wetDryMix;
  final bool isModelReady;
  final double modelDownloadProgress;
  final bool isRecording;
  final bool isProcessing;
  final double processProgress;
  final String statusText;
  final String? originalPath;
  final String? cleanedPath;
  final String? finalMixedPath;
  final bool playCleaned;
  final bool isPlaying;

  const StudioState({
    this.inputMode = InputMode.recorder,
    this.preset = DenoisePreset.strong,
    this.wetDryMix = 0.85,
    this.isModelReady = false,
    this.modelDownloadProgress = 0.0,
    this.isRecording = false,
    this.isProcessing = false,
    this.processProgress = 0.0,
    this.statusText = 'Tayyor',
    this.originalPath,
    this.cleanedPath,
    this.finalMixedPath,
    this.playCleaned = true,
    this.isPlaying = false,
  });

  StudioState copyWith({
    InputMode? inputMode,
    DenoisePreset? preset,
    double? wetDryMix,
    bool? isModelReady,
    double? modelDownloadProgress,
    bool? isRecording,
    bool? isProcessing,
    double? processProgress,
    String? statusText,
    String? originalPath,
    String? cleanedPath,
    String? finalMixedPath,
    bool? playCleaned,
    bool? isPlaying,
  }) {
    return StudioState(
      inputMode: inputMode ?? this.inputMode,
      preset: preset ?? this.preset,
      wetDryMix: wetDryMix ?? this.wetDryMix,
      isModelReady: isModelReady ?? this.isModelReady,
      modelDownloadProgress: modelDownloadProgress ?? this.modelDownloadProgress,
      isRecording: isRecording ?? this.isRecording,
      isProcessing: isProcessing ?? this.isProcessing,
      processProgress: processProgress ?? this.processProgress,
      statusText: statusText ?? this.statusText,
      originalPath: originalPath ?? this.originalPath,
      cleanedPath: cleanedPath ?? this.cleanedPath,
      finalMixedPath: finalMixedPath ?? this.finalMixedPath,
      playCleaned: playCleaned ?? this.playCleaned,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}
