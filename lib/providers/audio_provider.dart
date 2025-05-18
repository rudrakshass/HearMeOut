import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_service.dart';

class AudioNotifier extends StateNotifier<AudioState> {
  final AudioService _audioService;

  AudioNotifier(this._audioService) : super(AudioState());

  Future<void> toggleRecording() async {
    if (state.isRecording) {
      await _audioService.stopRecording();
      state = state.copyWith(isRecording: false);
    } else {
      await _audioService.startRecording();
      state = state.copyWith(isRecording: true);
    }
  }

  Future<void> togglePlayback() async {
    if (state.isPlaying) {
      await _audioService.stopPlayback();
      state = state.copyWith(isPlaying: false);
    } else {
      await _audioService.startPlayback();
      state = state.copyWith(isPlaying: true);
    }
  }
}

class AudioState {
  final bool isRecording;
  final bool isPlaying;

  AudioState({
    this.isRecording = false,
    this.isPlaying = false,
  });

  AudioState copyWith({
    bool? isRecording,
    bool? isPlaying,
  }) {
    return AudioState(
      isRecording: isRecording ?? this.isRecording,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  return AudioNotifier(audioService);
}); 