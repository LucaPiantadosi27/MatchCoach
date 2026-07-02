import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/recording_provider.dart';
import 'dart:async';

class RecordingPlayer extends ConsumerStatefulWidget {
  const RecordingPlayer({super.key});

  @override
  ConsumerState<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends ConsumerState<RecordingPlayer> {
  Timer? _playbackTimer;
  DateTime? _lastTick;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _lastTick = DateTime.now();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      final dt = now.difference(_lastTick!).inMilliseconds / 1000.0;
      _lastTick = now;
      ref.read(recordingProvider.notifier).updatePlayback(dt);
      setState(() {});
    });
  }

  void _stopPlaybackTimer() {
    _playbackTimer?.cancel();
  }

  bool _wasPlayingBeforeDrag = false;

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingProvider);
    final recordingNotifier = ref.read(recordingProvider.notifier);
    final isPlaying = recordingState == RecordingState.playing;
    final isPaused = recordingState == RecordingState.paused;
    final playbackTime = recordingNotifier.playbackTime;
    final duration = recordingNotifier.duration;

    // Gestisci il timer in base allo stato
    if (isPlaying && !_wasPlayingBeforeDrag) {
      if (_playbackTimer == null || !_playbackTimer!.isActive) {
        _startPlaybackTimer();
      }
    } else {
      _stopPlaybackTimer();
    }

    if (duration == 0) {
      return const SizedBox.shrink();
    }

    // Controlla se è una registrazione palesemente "a step" (durata intera netta o quasi)
    final bool isExactSteps = duration == duration.roundToDouble();

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.shade100, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Riga 1: Timeline
            Row(
              children: [
                Text(
                  _formatTime(playbackTime),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: Colors.purple.shade600,
                      inactiveTrackColor: Colors.purple.shade100,
                      thumbColor: Colors.purple.shade600,
                    ),
                    child: Slider(
                      value: playbackTime.clamp(0.0, duration),
                      min: 0,
                      max: duration,
                      divisions: isExactSteps && duration > 0 ? duration.toInt() : null,
                      onChangeStart: (value) {
                         setState(() {
                           _wasPlayingBeforeDrag = isPlaying;
                         });
                         if (isPlaying) {
                           recordingNotifier.pausePlayback();
                         }
                      },
                      onChanged: (value) {
                        // Se era puramente a step ma per qualche motivo perde aderenza, forza il rounding morbido.
                        double snappedValue = value;
                        if (isExactSteps) {
                           snappedValue = value.roundToDouble();
                        }
                        recordingNotifier.seekPlayback(snappedValue);
                        setState(() {});
                      },
                      onChangeEnd: (value) {
                         if (_wasPlayingBeforeDrag) {
                            recordingNotifier.resumePlayback();
                         }
                         setState(() {
                           _wasPlayingBeforeDrag = false;
                         });
                      },
                    ),
                  ),
                ),
                Text(
                  _formatTime(duration),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Riga 2: Controlli
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous Step
                _buildControlButton(
                  icon: Icons.skip_previous_rounded,
                  onPressed: () {
                    recordingNotifier.skipToPreviousStep();
                    setState(() {});
                  },
                  color: Colors.purple.shade50,
                  iconColor: Colors.purple.shade700,
                  size: 36,
                  iconSize: 22,
                ),
                const SizedBox(width: 20),
                // Play / Pause
                _buildControlButton(
                  icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  onPressed: () {
                    if (isPlaying) {
                      recordingNotifier.pausePlayback();
                    } else if (isPaused) {
                      recordingNotifier.resumePlayback();
                    } else {
                      recordingNotifier.startPlayback();
                    }
                  },
                  color: Colors.purple.shade700,
                  iconColor: Colors.white,
                  size: 48,
                  iconSize: 28,
                  elevation: 3,
                ),
                const SizedBox(width: 20),
                // Next Step
                _buildControlButton(
                  icon: Icons.skip_next_rounded,
                  onPressed: () {
                    recordingNotifier.skipToNextStep();
                    setState(() {});
                  },
                  color: Colors.purple.shade50,
                  iconColor: Colors.purple.shade700,
                  size: 36,
                  iconSize: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required Color iconColor,
    double size = 40,
    double iconSize = 24,
    double elevation = 1,
  }) {
    return Material(
      elevation: elevation,
      shadowColor: color.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
