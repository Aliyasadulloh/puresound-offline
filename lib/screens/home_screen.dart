import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models/audio_models.dart';
import '../providers/studio_provider.dart';
import '../widgets/glass_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  VideoPlayerController? _videoController;
  String? _loadedVideoPath;

  Future<void> _syncVideo(String? path) async {
    if (path == null || path == _loadedVideoPath) return;
    final oldPos = _videoController?.value.position ?? Duration.zero;
    final wasPlaying = _videoController?.value.isPlaying ?? false;

    await _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(path));
    await _videoController!.initialize();
    await _videoController!.seekTo(oldPos);
    if (wasPlaying) await _videoController!.play();
    _loadedVideoPath = path;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioProvider);
    final notifier = ref.read(studioProvider.notifier);

    if (state.inputMode == InputMode.video) {
      final activeVideo = state.playCleaned ? state.finalMixedPath : state.originalPath;
      if (activeVideo != null && activeVideo != _loadedVideoPath) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncVideo(activeVideo));
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.graphic_eq, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text('PureSound Offline', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: state.isModelReady ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              state.isModelReady ? '100% OFFLINE AI' : 'YUKLANMOQDA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: state.isModelReady ? Colors.greenAccent : Colors.amberAccent,
              ),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<InputMode>(
            segments: const [
              ButtonSegment(value: InputMode.recorder, icon: Icon(Icons.mic), label: Text('Diktofon')),
              ButtonSegment(value: InputMode.audio, icon: Icon(Icons.audiotrack), label: Text('Audio')),
              ButtonSegment(value: InputMode.video, icon: Icon(Icons.videocam), label: Text('Video')),
            ],
            selected: {state.inputMode},
            onSelectionChanged: (s) => notifier.setInputMode(s.first),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: [
                if (state.inputMode == InputMode.recorder)
                  GestureDetector(
                    onTap: state.isModelReady ? notifier.toggleRecording : null,
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: state.isRecording ? Colors.redAccent : const Color(0xFF38BDF8),
                      child: Icon(
                        state.isRecording ? Icons.stop : Icons.mic,
                        size: 38,
                        color: Colors.black,
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: state.isModelReady ? notifier.pickFile : null,
                    icon: Icon(state.inputMode == InputMode.video ? Icons.video_file : Icons.audio_file),
                    label: Text(
                      state.inputMode == InputMode.video
                          ? 'Video tanlash (.mp4, .mov, .mkv)'
                          : 'Audio tanlash (.mp3, .wav, .m4a)',
                    ),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                const SizedBox(height: 14),
                Text(state.statusText, style: const TextStyle(color: Colors.white70)),
                if (state.isProcessing || !state.isModelReady) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: state.isModelReady ? state.processProgress : state.modelDownloadProgress,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tozalash rejimi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: DenoisePreset.values.map((preset) {
                    final selected = state.preset == preset;
                    return ChoiceChip(
                      label: Text(preset.title),
                      selected: selected,
                      onSelected: (_) => notifier.setPreset(preset),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Wet / Dry Mix (AI kuchi)'),
                    Text(
                      '${(state.wetDryMix * 100).round()}%',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Slider(
                  value: state.wetDryMix,
                  onChanged: notifier.setWetDry,
                  onChangeEnd: (_) => notifier.commitWetDry(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (state.finalMixedPath != null)
            GlassCard(
              child: Column(
                children: [
                  if (state.inputMode == InputMode.video && _videoController?.value.isInitialized == true)
                    AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Original'),
                        selected: !state.playCleaned,
                        onSelected: (_) => notifier.toggleBeforeAfter(false),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Tozalangan (AI)'),
                        selected: state.playCleaned,
                        onSelected: (_) => notifier.toggleBeforeAfter(true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton.filled(
                        onPressed: () {
                          if (state.inputMode == InputMode.video && _videoController != null) {
                            _videoController!.value.isPlaying
                                ? _videoController!.pause()
                                : _videoController!.play();
                            setState(() {});
                          } else {
                            notifier.togglePlayPause();
                          }
                        },
                        icon: Icon(
                          (state.inputMode == InputMode.video
                                  ? (_videoController?.value.isPlaying ?? false)
                                  : state.isPlaying)
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                      ),
                      if (state.inputMode == InputMode.video)
                        OutlinedButton.icon(
                          onPressed: () => notifier.exportAndShare(saveToGallery: true),
                          icon: const Icon(Icons.save_alt),
                          label: const Text('Galereyaga'),
                        ),
                      FilledButton.icon(
                        onPressed: () => notifier.exportAndShare(saveToGallery: false),
                        icon: const Icon(Icons.share),
                        label: const Text('Ulashish'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
