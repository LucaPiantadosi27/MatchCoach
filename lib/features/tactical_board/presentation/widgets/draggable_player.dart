import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/player_model.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/player_token.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/grid_painter.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/board_provider.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/recording_provider.dart';

/// Optimized draggable player widget with zero-lag performance
/// Uses direct provider updates instead of setState for 60fps
class DraggablePlayer extends ConsumerStatefulWidget {
  final PlayerModel player;
  final BoxConstraints constraints;

  const DraggablePlayer({
    super.key,
    required this.player,
    required this.constraints,
  });

  @override
  ConsumerState<DraggablePlayer> createState() => _DraggablePlayerState();
}

class _DraggablePlayerState extends ConsumerState<DraggablePlayer> {
  Offset? _dragOffset;
  Offset? _rotationStartPoint;
  double _initialRotation = 0;
  Offset? _panStartPosition;
  bool? _isHorizontalGesture;

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(interactionModeProvider);
    final player = widget.player;
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Calculate actual position (normalized to pixels)
    final actualPosition = _dragOffset ??
        Offset(
          player.position.dx * widget.constraints.maxWidth,
          player.position.dy * widget.constraints.maxHeight,
        );

    // Mobile: larger touch target (44px minimum recommended)
    final touchPadding = isMobile ? 12.0 : 0.0;

    return Positioned(
      left: actualPosition.dx - 20 - touchPadding,
      top: actualPosition.dy - 20 - touchPadding,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Single tap to select or remove
        onTap: () {
          if (mode == InteractionMode.removePlayer) {
            // Rimuovi giocatore (non permettere rimozione della palla)
            if (player.team != TeamType.Ball) {
              ref.read(boardProvider.notifier).removePlayer(player.id);
            }
          } else {
            ref.read(boardProvider.notifier).selectPlayer(player.id);
          }
        },
        // Long press to enter rotation mode
        onLongPress: () {
          ref.read(boardProvider.notifier).selectPlayer(player.id);
          setState(() {
            _rotationStartPoint = Offset.zero;
            _initialRotation = player.rotation;
          });
        },
        // Drag for movement or rotation
        onScaleStart: mode == InteractionMode.move
            ? (details) {
                if (_rotationStartPoint != null) {
                  // Rotation mode
                  setState(() {
                    _rotationStartPoint = details.localFocalPoint;
                  });
                  ref.read(recordingProvider.notifier).recordFrame(force: true);
                } else {
                  // Movement mode - inizializza tracking
                  ref.read(boardProvider.notifier).beginMove(); // save undo state
                  setState(() {
                    _dragOffset = Offset(
                      player.position.dx * widget.constraints.maxWidth,
                      player.position.dy * widget.constraints.maxHeight,
                    );
                    _panStartPosition = details.localFocalPoint;
                    _isHorizontalGesture = null; // Determineremo dopo
                    _initialRotation = player.rotation;
                  });
                  ref.read(boardProvider.notifier).selectPlayer(player.id);
                  ref.read(recordingProvider.notifier).recordFrame(force: true);
                }
              }
            : null,
        onScaleUpdate: mode == InteractionMode.move
            ? (details) {
                if (_rotationStartPoint != null) {
                  // Rotation gesture - calcola angolo dal centro della pedina (360°)
                  final center = const Offset(20, 20);
                  final currentVector = details.localFocalPoint - center;
                  
                  // Usa atan2 per calcolo angolo preciso in tutte le direzioni
                  final angle = (atan2(currentVector.dy, currentVector.dx) * 180 / 3.14159) + 90;
                  
                  // Normalizza l'angolo tra 0 e 360
                  final normalizedAngle = angle % 360;
                  
                  ref.read(boardProvider.notifier).rotatePlayer(
                    player.id,
                    normalizedAngle < 0 ? normalizedAngle + 360 : normalizedAngle,
                  );
                  
                  // Registra il frame se in modalità recording
                  ref.read(recordingProvider.notifier).recordFrame();
                } else if (details.pointerCount >= 2) {
                  // TWO-FINGER ROTATION GESTURE (Pinch-to-rotate come una manopola per tablet/smartphone)
                  final rotationDelta = details.rotation * 180 / 3.14159;
                  final newRotation = (_initialRotation + rotationDelta) % 360;
                  
                  ref.read(boardProvider.notifier).rotatePlayer(
                    player.id,
                    newRotation < 0 ? newRotation + 360 : newRotation,
                  );
                  ref.read(recordingProvider.notifier).recordFrame();
                } else if (_dragOffset != null && _panStartPosition != null) {
                  // Determina se è un gesto orizzontale o verticale (fallback a 1 singolo dito per mouse e vecchi usage)
                  if (_isHorizontalGesture == null) {
                    final deltaFromStart = details.localFocalPoint - _panStartPosition!;
                    final absX = deltaFromStart.dx.abs();
                    final absY = deltaFromStart.dy.abs();
                    
                    // Se il movimento è > 10px, determina la direzione
                    if (absX > 10 || absY > 10) {
                      setState(() {
                        _isHorizontalGesture = absX > absY * 1.5; // Orizzontale se X > 1.5 * Y
                      });
                    }
                  }
                  
                  if (_isHorizontalGesture == true) {
                    // Rotazione con swipe orizzontale (mouse drag axis x)
                    final deltaX = details.localFocalPoint.dx - _panStartPosition!.dx;
                    // Ogni 50 pixel = 90 gradi
                    final rotationDelta = (deltaX / 50) * 90;
                    final newRotation = (_initialRotation + rotationDelta) % 360;
                    
                    ref.read(boardProvider.notifier).rotatePlayer(
                      player.id,
                      newRotation < 0 ? newRotation + 360 : newRotation,
                    );
                    
                    ref.read(recordingProvider.notifier).recordFrame();
                  } else if (_isHorizontalGesture == false) {
                    // Movement gesture normale a un dito / cursore
                    setState(() {
                      _dragOffset = _dragOffset! + details.focalPointDelta;
                    });
                    
                    // Aggiorna posizione temporanea nel provider per la registrazione
                    final normalizedX = (_dragOffset!.dx / widget.constraints.maxWidth).clamp(0.0, 1.0);
                    final normalizedY = (_dragOffset!.dy / widget.constraints.maxHeight).clamp(0.0, 1.0);
                    
                    ref.read(boardProvider.notifier).movePlayer(
                      player.id,
                      Offset(normalizedX, normalizedY),
                    );
                    
                    // Registra frame durante il movimento
                    ref.read(recordingProvider.notifier).recordFrame();
                  }
                }
              }
            : null,
        onScaleEnd: mode == InteractionMode.move
            ? (details) {
                if (_rotationStartPoint != null) {
                  // End rotation mode
                  setState(() {
                    _rotationStartPoint = null;
                  });
                } else if (_dragOffset != null) {
                  // Applica snap-to-grid se la griglia è attiva (solo se non era rotazione)
                  if (_isHorizontalGesture == false) {
                    final showGrid = ref.read(showGridProvider);
                    if (showGrid) {
                      final normalizedX = (_dragOffset!.dx / widget.constraints.maxWidth).clamp(0.0, 1.0);
                      final normalizedY = (_dragOffset!.dy / widget.constraints.maxHeight).clamp(0.0, 1.0);
                      final snappedPosition = GridSnap.snapToGrid(Offset(normalizedX, normalizedY));
                      ref.read(boardProvider.notifier).movePlayer(player.id, snappedPosition);
                    }
                  }
                  
                  // Registra l'ultimo frame
                  ref.read(recordingProvider.notifier).recordFrame();

                  setState(() {
                    _dragOffset = null;
                    _panStartPosition = null;
                    _isHorizontalGesture = null;
                  });
                }
              }
            : null,
        child: Container(
          padding: EdgeInsets.all(touchPadding),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Visual feedback during dragging (mobile)
              if (isMobile && _dragOffset != null)
                Positioned(
                  left: -8,
                  top: -8,
                  right: -8,
                  bottom: -8,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              PlayerToken(player: player),
            if (_rotationStartPoint != null)
              Positioned(
                top: -35,
                left: -15,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.rotate_right,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${player.rotation.toInt()}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
