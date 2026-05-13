import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';
import 'package:lavagna_tattica/features/premium/presentation/paywall_bottom_sheet.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/drawing_path.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/player_model.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/field_background.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/field_painter.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/drawing_painter.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/draggable_player.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/draggable_equipment.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/grid_painter.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/scheme_preview_dialog.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/sidebar_panel.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/schemes_list_page.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/board_provider.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/recording_provider.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/sidebar_provider.dart';
import 'package:lavagna_tattica/features/tactical_board/services/export_service.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/board_state.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'dart:async';
import 'dart:ui' as ui;

class TacticalBoardPage extends ConsumerStatefulWidget {
  const TacticalBoardPage({super.key});

  @override
  ConsumerState<TacticalBoardPage> createState() => _TacticalBoardPageState();
}

class _TacticalBoardPageState extends ConsumerState<TacticalBoardPage> {
  DrawingPath? _currentPath;
  Timer? _recordingTimer;
  final GlobalKey _snapshotKey = GlobalKey();

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details, BoxConstraints constraints) {
    final mode = ref.read(interactionModeProvider);
    if (mode != InteractionMode.draw) return;

    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;

    setState(() {
      _currentPath = DrawingPath(
        points: [Offset(x, y)],
        lineStyle: ref.read(selectedLineStyleProvider),
        color: ref.read(selectedColorProvider),
        strokeWidth: ref.read(selectedStrokeWidthProvider),
        hasArrow: ref.read(hasArrowProvider),
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_currentPath == null) return;

    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;

    setState(() {
      _currentPath = DrawingPath(
        points: [..._currentPath!.points, Offset(x, y)],
        lineStyle: _currentPath!.lineStyle,
        color: _currentPath!.color,
        strokeWidth: _currentPath!.strokeWidth,
        hasArrow: _currentPath!.hasArrow,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentPath != null && _currentPath!.points.length > 1) {
      ref.read(boardProvider.notifier).addPath(_currentPath!);
    }
    setState(() {
      _currentPath = null;
    });
  }

  /// Breakpoint: below this width we use mobile layout
  static const double _mobileBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    final boardState = ref.watch(boardProvider);
    final mode = ref.watch(interactionModeProvider);
    final selectedColor = ref.watch(selectedColorProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < _mobileBreakpoint;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
              title: Text(
                boardState.name,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                _buildMobileRecordingButton(context, boardState),
                ..._buildAppBarActions(context, boardState),
              ],
            )
          : null,
      drawer: isMobile
          ? Drawer(
              width: 280,
              child: SafeArea(
                child: Column(
                  children: [
                    // Drawer header with back button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () {
                              Navigator.of(context).pop(); // close drawer
                              context.go('/home');
                            },
                            tooltip: 'Torna alla Home',
                          ),
                          const Expanded(
                            child: Text(
                              'MatchCoach-AI',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    const Expanded(child: SidebarPanel()),
                  ],
                ),
              ),
            )
          : null,
      body: isMobile
          ? _buildMobileLayout(context, boardState, mode, selectedColor)
          : _buildDesktopLayout(context, boardState, mode, selectedColor),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, boardState) {
    final recordingState = ref.watch(recordingProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < _mobileBreakpoint;
    
    return [
          // Recording controls (ONLY on desktop - mobile has them in title)
          if (!isMobile && recordingState == RecordingState.idle)
            IconButton(
              icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
              tooltip: 'Inizia Registrazione',
              onPressed: () {
                ref.read(recordingProvider.notifier).startRecording();
                _recordingTimer = Timer.periodic(
                  const Duration(milliseconds: 100),
                  (_) => ref.read(recordingProvider.notifier).recordFrame(),
                );
              },
            ),
          if (!isMobile && recordingState == RecordingState.recording)
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              tooltip: 'Ferma Registrazione',
              onPressed: () {
                _recordingTimer?.cancel();
                ref.read(recordingProvider.notifier).stopRecording();
              },
            ),
          if (!isMobile && recordingState == RecordingState.recording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'REC',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Annulla ultima azione',
            onPressed: () => ref.read(boardProvider.notifier).undo(),
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Ripristina posizioni di partenza',
            onPressed: () => _confirmResetPlayers(context),
          ),
          IconButton(
            icon: const Icon(Icons.photo_camera_rounded),
            tooltip: 'Snapshot campo (PNG)',
            onPressed: () => _captureSnapshot(boardState.name),
          ),
        ];
  }

  Widget _buildMobileLayout(
    BuildContext context,
    boardState,
    InteractionMode mode,
    Color selectedColor,
  ) {
    return Container(
      color: Colors.black,
      child: RotatedBox(
        quarterTurns: 1,
        child: _buildField(boardState),
      ),
    );
  }

  /// Mobile recording button - LARGE and VISIBLE for touch
  Widget _buildMobileRecordingButton(BuildContext context, BoardState boardState) {
    final recordingState = ref.watch(recordingProvider);
    final isNewScheme = ref.watch(isNewSchemeProvider);
    final isRecording = recordingState == RecordingState.recording;
    final stepCount = ref.watch(recordingStepCountProvider);

    if (!isNewScheme) return const SizedBox.shrink();

    if (isRecording) {
      // Recording mode: STEP button + STOP button
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // STEP button - large and orange
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref.read(recordingProvider.notifier).addStep(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF9A826), Color(0xFFF57C00)]),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF57C00).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text('STEP ${stepCount + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // STOP button - large and red
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (mounted) {
                  _handleMobileStopRecording(context, boardState);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFB71C1C).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stop_circle, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text('STOP', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Idle mode: START button
    final hasRecording = boardState.recording != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasRecording ? null : () {
          ref.read(recordingProvider.notifier).startRecording();
          _recordingTimer = Timer.periodic(
            const Duration(milliseconds: 100),
            (_) => ref.read(recordingProvider.notifier).recordFrame(),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: hasRecording ? const Color(0xFF388E3C) : const Color(0xFFB71C1C),
            borderRadius: BorderRadius.circular(8),
            boxShadow: hasRecording ? null : [
              BoxShadow(color: const Color(0xFFB71C1C).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasRecording ? Icons.check_circle : Icons.fiber_manual_record,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                hasRecording ? 'SALVATO' : 'REC',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact mode icon for mobile toolbar (smaller than default)
  Widget _buildModeIconCompact(BuildContext context, InteractionMode mode, IconData icon, String label) {
    final currentMode = ref.watch(interactionModeProvider);
    final isSelected = currentMode == mode;
    return InkWell(
      onTap: () => ref.read(interactionModeProvider.notifier).state = mode,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.green : Colors.grey, size: 22),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isSelected ? Colors.green : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureSnapshot(String fileName) async {
    await ExportService.downloadSnapshot(
      _snapshotKey,
      context,
      fileName: fileName,
      ref: ref,
    );
  }

  Future<void> _confirmResetPlayers(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripristina posizioni'),
        content: const Text(
          'Le pedine torneranno alle posizioni di partenza.\nI disegni e le attrezzature rimarranno invariati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Ripristina'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(boardProvider.notifier).resetPlayers();
    }
  }

  Future<void> _handleMobileStopRecording(BuildContext context, BoardState boardState) async {
    _recordingTimer?.cancel();
    final recording = ref.read(recordingProvider.notifier).stopRecording();
    final updatedBoardState = boardState.copyWith(recording: recording);
    ref.read(boardProvider.notifier).updateState(updatedBoardState);

    if (!mounted) {
      print('❌ Widget not mounted, cannot show dialog');
      return;
    }

    print('✅ Showing save dialog for recording: ${recording.duration}s');

    final TextEditingController nameController = TextEditingController(
      text: 'Schema ${DateTime.now().day}/${DateTime.now().month} ${DateTime.now().hour}:${DateTime.now().minute}',
    );

    final String? name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('💾 Salva Schema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: AppTheme.accentGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Durata: ${recording.duration.toStringAsFixed(1)}s',
                    style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Nome schema',
                hintText: 'Es: Schema 4-2',
                prefixIcon: const Icon(Icons.edit, size: 20),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              autofocus: true,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla', style: TextStyle(fontSize: 15)),
            ),
          ),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, nameController.text),
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Salva', style: TextStyle(fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && context.mounted) {
      final user = ref.read(userProvider).valueOrNull;
      if (user == null) return;
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      try {
        await ref.read(recordingRepositoryProvider).saveRecording(
          userId: user.id,
          name: name,
          recording: updatedBoardState.recording!,
        );
        await ref.read(userProvider.notifier).incrementSchemesCount();
        ref.invalidate(userRecordingsProvider);
        
        // Hide loading
        if (context.mounted) Navigator.pop(context);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Schema salvato!')),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          ref.read(boardProvider.notifier).clearRecording();
        }
      } catch (e) {
        // Hide loading
        if (context.mounted) Navigator.pop(context);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Errore: $e')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } else {
      ref.read(boardProvider.notifier).clearRecording();
    }
  }

  Widget _buildCompactTeamButton(BuildContext context, TeamType team, String label, Color color) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: () => ref.read(boardProvider.notifier).addPlayer(team),
        icon: const Icon(Icons.add, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  /// Button that opens a popup with all 12 line styles
  Widget _buildLineStyleButton(BuildContext context) {
    final lineStyle = ref.watch(selectedLineStyleProvider);
    
    return InkWell(
      onTap: () {
        _showLineStylePicker(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Center(
              child: _getLineStyleIcon(lineStyle),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Stile',
            style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showLineStylePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stile Linea', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Line styles grid
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: LineStyle.values.map((style) {
                  final isSelected = ref.read(selectedLineStyleProvider) == style;
                  return InkWell(
                    onTap: () {
                      ref.read(selectedLineStyleProvider.notifier).state = style;
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.green : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _getLineStyleIcon(style),
                          const SizedBox(height: 2),
                          Text(
                            _getLineStyleName(style),
                            style: TextStyle(
                              fontSize: 8,
                              color: isSelected ? Colors.green : Colors.grey.shade700,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Stroke width slider
              Row(
                children: [
                  const Icon(Icons.line_weight, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Spessore:', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setSliderState) {
                        var strokeWidth = ref.read(selectedStrokeWidthProvider);
                        return Slider(
                          value: strokeWidth,
                          min: 1.0,
                          max: 10.0,
                          divisions: 9,
                          label: strokeWidth.toStringAsFixed(0),
                          onChanged: (value) {
                            setSliderState(() {});
                            ref.read(selectedStrokeWidthProvider.notifier).state = value;
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              // Arrow toggle
              StatefulBuilder(
                builder: (context, setToggleState) {
                  var hasArrow = ref.read(hasArrowProvider);
                  return SwitchListTile(
                    title: const Text('Freccia direzionale', style: TextStyle(fontSize: 13)),
                    secondary: const Icon(Icons.arrow_forward, size: 18),
                    value: hasArrow,
                    dense: true,
                    onChanged: (value) {
                      setToggleState(() {});
                      ref.read(hasArrowProvider.notifier).state = value;
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getLineStyleIcon(LineStyle style) {
    // Simple visual representation of each line style
    return CustomPaint(
      size: const Size(24, 12),
      painter: _LineStylePreviewPainter(style),
    );
  }

  String _getLineStyleName(LineStyle style) {
    switch (style) {
      case LineStyle.solid: return 'Solida';
      case LineStyle.dashed: return 'Tratteg.';
      case LineStyle.dotted: return 'Punteg.';
      case LineStyle.dashDot: return '— •';
      case LineStyle.dashDotDot: return '— ••';
      case LineStyle.wavy: return 'Ondulata';
      case LineStyle.arrow: return 'Freccia';
      case LineStyle.doubleArrow: return '⇄';
      case LineStyle.curved: return 'Curva';
      case LineStyle.zigzag: return 'Zigzag';
      case LineStyle.thick: return 'Larga';
      case LineStyle.highlighter: return 'Evid.';
    }
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    boardState,
    InteractionMode mode,
    Color selectedColor,
  ) {
    final sidebarVisible = ref.watch(sidebarVisibleProvider);
    
    return Row(
      children: [
        // Sidebar con sezioni organizzate
        if (sidebarVisible) const SidebarPanel(),
        // Full-width field
        Expanded(
          child: Column(
            children: [
              // Top toolbar con tools
              Container(
                height: 50,
                color: Theme.of(context).cardColor,
                child: Row(
                  children: [
                    // Back to home button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Torna alla Home',
                      onPressed: () => context.go('/home'),
                    ),
                    const SizedBox(width: 4),
                    // Sidebar toggle button
                    IconButton(
                      icon: Icon(sidebarVisible ? Icons.menu_open : Icons.menu),
                      tooltip: sidebarVisible ? 'Nascondi pannello' : 'Mostra pannello',
                      onPressed: () {
                        ref.read(sidebarVisibleProvider.notifier).state = !sidebarVisible;
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      boardState.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.undo),
                      onPressed: () => ref.read(boardProvider.notifier).undo(),
                      tooltip: 'Annulla ultima azione',
                    ),
                    IconButton(
                      icon: const Icon(Icons.restart_alt_rounded),
                      onPressed: () => _confirmResetPlayers(context),
                      tooltip: 'Ripristina posizioni di partenza',
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_camera_rounded),
                      onPressed: () => _captureSnapshot(ref.read(boardProvider).name),
                      tooltip: 'Snapshot campo (PNG)',
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              // Field
              Expanded(
                child: _buildField(boardState),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField(boardState) {
    final background = ref.watch(fieldBackgroundProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: GestureDetector(
            onPanStart: (d) => _onPanStart(d, constraints),
            onPanUpdate: (d) => _onPanUpdate(d, constraints),
            onPanEnd: _onPanEnd,
            child: RepaintBoundary(
              key: _snapshotKey,
              child: Stack(
                children: [
                  // Field with selected background
                  FieldBackground$View(
                    background: background,
                    viewMode: ref.watch(fieldViewModeProvider),
                  ),
                  // Grid overlay
                  CustomPaint(
                    size: Size.infinite,
                    painter: GridPainter(
                      showGrid: ref.watch(showGridProvider),
                    ),
                  ),
                  // Drawings
                  CustomPaint(
                    size: Size.infinite,
                    painter: DrawingPainter(
                      paths: boardState.paths,
                      currentPath: _currentPath,
                    ),
                  ),
                  // Players
                  ...boardState.players.map((player) {
                    return DraggablePlayer(
                      key: ValueKey(player.id),
                      player: player,
                      constraints: constraints,
                    );
                  }),
                  // Equipment
                  ...boardState.equipment.map((equipment) {
                    return DraggableEquipment(
                      key: ValueKey(equipment.id),
                      equipment: equipment,
                      constraints: constraints,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveScheme(BuildContext context, boardState) async {
    final user = ref.read(userProvider).valueOrNull;
    if (user == null) return;

    if (!user.canSaveScheme) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => const PaywallBottomSheet(),
      );
      return;
    }

    // Prima chiedi il nome
    final TextEditingController nameController =
        TextEditingController(text: boardState.name);
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nome Schema'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Nome schema'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Avanti'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    // Aggiorna il nome nello stato
    final updatedState = boardState.copyWith(name: name);

    // Mostra preview
    if (!context.mounted) return;
    
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SchemePreviewDialog(
        boardState: updatedState,
        onSave: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (shouldSave == true && context.mounted) {
      // Aggiorna solo il nome nello stato
      ref.read(boardProvider.notifier).state = updatedState;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schema aggiornato! Usa il pulsante REGISTRA per salvare la registrazione.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildModeIcon(
    BuildContext context,
    InteractionMode mode,
    IconData icon,
    String label,
  ) {
    final currentMode = ref.watch(interactionModeProvider);
    final isSelected = currentMode == mode;

    return InkWell(
      onTap: () => ref.read(interactionModeProvider.notifier).state = mode,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.green : Colors.grey,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.green : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small custom painter to preview a line style in the picker grid
class _LineStylePreviewPainter extends CustomPainter {
  final LineStyle style;
  _LineStylePreviewPainter(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    final start = Offset(0, y);
    final end = Offset(size.width, y);

    switch (style) {
      case LineStyle.solid:
        canvas.drawLine(start, end, paint);
        break;
      case LineStyle.dashed:
        _drawPreviewDashed(canvas, start, end, paint, 4, 3);
        break;
      case LineStyle.dotted:
        final dotPaint = Paint()..color = paint.color..style = PaintingStyle.fill;
        for (double x = 0; x < size.width; x += 5) {
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
        break;
      case LineStyle.dashDot:
        _drawPreviewDashed(canvas, start, Offset(size.width * 0.4, y), paint, 4, 2);
        canvas.drawCircle(Offset(size.width * 0.5, y), 1.2, Paint()..color = paint.color);
        _drawPreviewDashed(canvas, Offset(size.width * 0.6, y), end, paint, 4, 2);
        break;
      case LineStyle.dashDotDot:
        canvas.drawLine(start, Offset(size.width * 0.3, y), paint);
        canvas.drawCircle(Offset(size.width * 0.45, y), 1.2, Paint()..color = paint.color);
        canvas.drawCircle(Offset(size.width * 0.55, y), 1.2, Paint()..color = paint.color);
        canvas.drawLine(Offset(size.width * 0.7, y), end, paint);
        break;
      case LineStyle.wavy:
        final wavePath = Path()..moveTo(0, y);
        for (double x = 0; x < size.width; x += 1) {
          wavePath.lineTo(x, y + 3 * _sin(x / 4));
        }
        canvas.drawPath(wavePath, paint);
        break;
      case LineStyle.arrow:
        canvas.drawLine(start, Offset(size.width - 4, y), paint);
        final arrowPath = Path()
          ..moveTo(size.width, y)
          ..lineTo(size.width - 6, y - 3)
          ..lineTo(size.width - 6, y + 3)
          ..close();
        canvas.drawPath(arrowPath, Paint()..color = paint.color..style = PaintingStyle.fill);
        break;
      case LineStyle.doubleArrow:
        canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), paint);
        // Right arrow
        final rightArrow = Path()
          ..moveTo(size.width, y)..lineTo(size.width - 5, y - 3)..lineTo(size.width - 5, y + 3)..close();
        canvas.drawPath(rightArrow, Paint()..color = paint.color..style = PaintingStyle.fill);
        // Left arrow
        final leftArrow = Path()
          ..moveTo(0, y)..lineTo(5, y - 3)..lineTo(5, y + 3)..close();
        canvas.drawPath(leftArrow, Paint()..color = paint.color..style = PaintingStyle.fill);
        break;
      case LineStyle.curved:
        final curvePath = Path()
          ..moveTo(0, y + 3)
          ..quadraticBezierTo(size.width / 2, y - 5, size.width, y + 3);
        canvas.drawPath(curvePath, paint);
        break;
      case LineStyle.zigzag:
        final zigPath = Path()..moveTo(0, y);
        for (double x = 0; x < size.width; x += 6) {
          final nextX = x + 3;
          zigPath.lineTo(nextX, y - 3);
          zigPath.lineTo(nextX + 3, y + 3);
        }
        canvas.drawPath(zigPath, paint);
        break;
      case LineStyle.thick:
        paint.strokeWidth = 4;
        canvas.drawLine(start, end, paint);
        break;
      case LineStyle.highlighter:
        paint.strokeWidth = 6;
        paint.color = paint.color.withOpacity(0.35);
        paint.strokeCap = StrokeCap.butt;
        canvas.drawLine(start, end, paint);
        break;
    }
  }

  void _drawPreviewDashed(Canvas canvas, Offset start, Offset end, Paint paint, double dash, double gap) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = (end - start).distance;
    final unitX = dx / length;
    final unitY = dy / length;
    double d = 0;
    while (d < length) {
      final s = Offset(start.dx + unitX * d, start.dy + unitY * d);
      final eD = (d + dash).clamp(0.0, length);
      final e = Offset(start.dx + unitX * eD, start.dy + unitY * eD);
      canvas.drawLine(s, e, paint);
      d += dash + gap;
    }
  }

  double _sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;

  @override
  bool shouldRepaint(covariant _LineStylePreviewPainter old) => old.style != style;
}
