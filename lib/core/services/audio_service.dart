import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:sound_stream/sound_stream.dart';
import 'dart:math' as math;

class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final PlayerStream _player = PlayerStream();
  StreamSubscription? _recordSubscription;
  bool _isPlayerInitialized = false;

  AudioService() {
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // OpenAI Realtime uses 24kHz, 1 channel, 16-bit PCM
    log('Initializing Player with 24kHz...', name: '###');
    await _player.initialize(
      sampleRate: 24000,
    );
    _isPlayerInitialized = true;
    log('Player Initialized', name: '###');
  }

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<Stream<Uint8List>> startRecordingStream() async {
    log('AudioService: Checking permissions...', name: '###');
    if (await hasPermission()) {
      log('AudioService: Starting recording stream...', name: '###');
      return await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 24000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ));
    }
    log('AudioService: Permission denied',
        name: '###', error: 'Permission denied');
    throw Exception('Microphone permission not granted');
  }

  Future<void> stopRecording() async {
    log('AudioService: Stopping recording', name: '###');
    await _audioRecorder.stop();
    _recordSubscription?.cancel();
  }

  Future<void> playAudioChunk(Uint8List bytes) async {
    if (!_isPlayerInitialized) {
      log('AudioService: Player not initialized, skipping chunk', name: '###');
      return;
    }

    // Write raw PCM bytes directly to the stream
    // log('AudioService: Playing chunk of ${bytes.length} bytes', name: '###'); // Verbose
    _player.writeChunk(bytes);
  }

  Future<void> emitSilence(int durationMs) async {
    if (!_isPlayerInitialized) return;
    // 24kHz * 1 channel * 2 bytes/sample * (ms/1000)
    final numSamples = (24000 * (durationMs / 1000)).toInt();
    final silence = Uint8List(numSamples * 2); // initialized to 0 by default
    _player.writeChunk(silence);
  }

  void clearQueue() {
    log('AudioService: Clearing buffer and stopping playback.', name: '###');
    _player.stop();
    _player.start(); // Restart immediately
  }

  /// Calculates the Root Mean Square (RMS) amplitude of a PCM chunk.
  /// Returns a value between 0.0 and 1.0 (normalized).
  double calculateRMS(Uint8List bytes) {
    if (bytes.isEmpty) return 0.0;

    // 16-bit PCM, signed, little-endian
    double sumSquared = 0.0;
    final buffer = bytes.buffer.asInt16List();

    for (var sample in buffer) {
      // Normalize to -1.0..1.0 range (32768 is max amplitude for 16-bit)
      double val = sample / 32768.0;
      sumSquared += val * val;
    }

    return math.sqrt(sumSquared / buffer.length);
  }

  Future<void> dispose() async {
    log('AudioService: Disposing', name: '###');
    try {
      if (_recordSubscription != null) {
        await _recordSubscription!.cancel();
        _recordSubscription = null;
      }
    } catch (e) {
      log('AudioService: Error cancelling subscription: $e', name: '###');
    }

    try {
      await _audioRecorder.dispose();
    } catch (e) {
      log('AudioService: Error disposing recorder: $e', name: '###');
    }

    if (_isPlayerInitialized) {
      try {
        _player.dispose();
      } catch (e) {
        log('AudioService: Error disposing player: $e', name: '###');
      }
      _isPlayerInitialized = false;
    }
  }
}
