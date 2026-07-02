import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/saved_recording.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/board_provider.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/recording_provider.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/recording_player.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/field_painter.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/drawing_painter.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/draggable_player.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/draggable_equipment.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/grid_painter.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/schemes_list_page.dart';
import 'dart:ui' as ui;

// ─── Colors ───────────────────────────────────────────────────────────────────
const _section = AppTheme.sidebarSectionColor;
const _border  = AppTheme.sidebarBorderColor;
const _accent  = AppTheme.accentGreen;
const _textPri = AppTheme.textPrimary;
const _textSec = AppTheme.textSecondary;

final selectedRecordingProvider =
    FutureProvider.family<SavedRecording?, String>((ref, recordingId) async {
  return ref.read(recordingRepositoryProvider).getRecording(recordingId);
});

class RecordingViewerPage extends ConsumerStatefulWidget {
  final String recordingId;

  const RecordingViewerPage({
    super.key,
    required this.recordingId,
  });

  @override
  ConsumerState<RecordingViewerPage> createState() =>
      _RecordingViewerPageState();
}

class _RecordingViewerPageState extends ConsumerState<RecordingViewerPage> {
  ui.Image? _backgroundImage;
  String? _loadedRecordingId;

  @override
  void initState() {
    super.initState();
    _loadBackgroundImage();
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final ByteData data =
          await rootBundle.load('assets/images/parquet-chiaro.jpg');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() => _backgroundImage = frame.image);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final recordingAsync =
        ref.watch(selectedRecordingProvider(widget.recordingId));

    return recordingAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        body: Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(title: const Text('Errore')),
        body: Center(
          child: Text('Errore: $err',
              style: const TextStyle(color: AppTheme.errorColor)),
        ),
      ),
      data: (savedRecording) {
        if (savedRecording == null) {
          return Scaffold(
            backgroundColor: AppTheme.surfaceColor,
            appBar: AppBar(title: const Text('Non Trovata')),
            body: const Center(
              child: Text('Registrazione non trovata',
                  style: TextStyle(color: _textSec)),
            ),
          );
        }

        // Load recording into provider
        if (_loadedRecordingId != widget.recordingId) {
          _loadedRecordingId = widget.recordingId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(recordingProvider.notifier)
                .loadRecording(savedRecording.recording);
          });
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 768;

        return Scaffold(
          backgroundColor: AppTheme.surfaceColor,
          appBar: isMobile ? _buildAppBar(savedRecording) : null,
          body: isMobile
              ? _buildPortraitLayout(savedRecording)
              : _buildLandscapeLayout(savedRecording),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(SavedRecording savedRecording) {
    return AppBar(
      backgroundColor: AppTheme.cardColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: _textSec),
        onPressed: () => context.go('/schemes'),
      ),
      title: Row(
        children: [
          const Icon(Icons.play_circle_rounded, size: 18, color: Color(0xFF9575CD)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              savedRecording.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textPri,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Landscape Layout (identical structure to TacticalBoardPage) ──────────
  Widget _buildLandscapeLayout(SavedRecording savedRecording) {
    return Row(
      children: [
        // ── Sidebar (same style as SidebarPanel / dark)
        Container(
          width: 260,
          decoration: const BoxDecoration(
            gradient: AppTheme.sidebarGradient,
            border: Border(right: BorderSide(color: _border, width: 1)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.video_library_rounded,
                              size: 13, color: Color(0xFF9575CD)),
                          const SizedBox(width: 6),
                          const Text(
                            'REGISTRAZIONE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _textSec,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        savedRecording.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPri,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.timer_rounded,
                              size: 11, color: _textSec),
                          const SizedBox(width: 4),
                          Text(
                            'Durata: ${savedRecording.recording.duration.toStringAsFixed(1)}s',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 12), color: _border),
                const SizedBox(height: 12),

                // ── Player controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.play_circle_outline_rounded, size: 13, color: _accent),
                        SizedBox(width: 6),
                        Text('CONTROLLI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textSec, letterSpacing: 1.2)),
                      ]),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: _section,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: const RecordingPlayer(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 12), color: _border),
                const SizedBox(height: 12),

                // ── Back button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GestureDetector(
                    onTap: () => context.go('/schemes'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9575CD),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9575CD).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 15, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Torna alle Registrazioni',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Field area
        Expanded(
          child: Column(
            children: [
              // Top toolbar (identical to TacticalBoardPage landscape)
              Container(
                height: 50,
                color: AppTheme.cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: _textSec),
                      tooltip: 'Torna alle Registrazioni',
                      onPressed: () => context.go('/schemes'),
                    ),
                    const Icon(Icons.play_circle_rounded,
                        size: 18, color: Color(0xFF9575CD)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        savedRecording.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPri,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _textSec),
                      tooltip: 'Chiudi',
                      onPressed: () => context.go('/schemes'),
                    ),
                  ],
                ),
              ),
              // Field
              Expanded(child: _buildField(savedRecording)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Portrait Layout ──────────────────────────────────────────────────────
  Widget _buildPortraitLayout(SavedRecording savedRecording) {
    return Column(
      children: [
        // Field (expandable) - rotated vertically on mobile
        Expanded(
          child: Container(
            color: Colors.black,
            child: RotatedBox(
              quarterTurns: 1,
              child: _buildField(savedRecording),
            ),
          ),
        ),
        // Controls panel at bottom
        Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardColor,
            border: Border(top: BorderSide(color: _border, width: 1)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info row
                  Row(
                    children: [
                      const Icon(Icons.play_circle_rounded,
                          size: 16, color: Color(0xFF9575CD)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          savedRecording.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textPri,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF7C4DFF).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${savedRecording.recording.duration.toStringAsFixed(1)}s',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Player
                  const RecordingPlayer(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Field painter ────────────────────────────────────────────────────────
  Widget _buildField(SavedRecording savedRecording) {
    final boardState = ref.watch(boardProvider);
    final currentBackground = ref.watch(fieldBackgroundProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: AppTheme.surfaceColor,
          child: Center(
            child: AspectRatio(
              aspectRatio: 2.0,
              child: LayoutBuilder(
                builder: (context, fieldConstraints) {
                  return Stack(
                    children: [
                      // Field background
                      CustomPaint(
                        size: Size(
                            fieldConstraints.maxWidth, fieldConstraints.maxHeight),
                        painter: FieldPainter(
                          background: currentBackground,
                          backgroundImage: _backgroundImage,
                          viewMode: ref.watch(fieldViewModeProvider),
                        ),
                      ),
                      // Grid overlay
                      CustomPaint(
                        size: Size(
                            fieldConstraints.maxWidth, fieldConstraints.maxHeight),
                        painter: GridPainter(
                          showGrid: ref.watch(showGridProvider),
                        ),
                      ),
                      // Drawings
                      CustomPaint(
                        size: Size(
                            fieldConstraints.maxWidth, fieldConstraints.maxHeight),
                        painter: DrawingPainter(paths: boardState.paths),
                      ),
                      // Players and Equipment (view-only)
                      AbsorbPointer(
                        child: Stack(
                          children: [
                            ...boardState.players.map((player) {
                              return DraggablePlayer(
                                key: ValueKey(player.id),
                                player: player,
                                constraints: fieldConstraints,
                              );
                            }),
                            ...boardState.equipment.map((equipment) {
                              return DraggableEquipment(
                                key: ValueKey(equipment.id),
                                equipment: equipment,
                                constraints: fieldConstraints,
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
