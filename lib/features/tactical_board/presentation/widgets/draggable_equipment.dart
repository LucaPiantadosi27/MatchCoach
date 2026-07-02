import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'package:lavagna_tattica/features/tactical_board/data/models/equipment_model.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/grid_painter.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/board_provider.dart';

class DraggableEquipment extends ConsumerStatefulWidget {
  final EquipmentModel equipment;
  final BoxConstraints constraints;

  const DraggableEquipment({
    super.key,
    required this.equipment,
    required this.constraints,
  });

  @override
  ConsumerState<DraggableEquipment> createState() => _DraggableEquipmentState();
}

class _DraggableEquipmentState extends ConsumerState<DraggableEquipment> {
  Offset? _dragOffset;
  Offset? _rotationStartPoint;
  // ignore: unused_field
  double _initialRotation = 0;

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(interactionModeProvider);
    final equipment = widget.equipment;

    // Calculate actual position (normalized to pixels)
    final actualPosition = _dragOffset ??
        Offset(
          equipment.position.dx * widget.constraints.maxWidth,
          equipment.position.dy * widget.constraints.maxHeight,
        );

    return Positioned(
      left: actualPosition.dx - 20,
      top: actualPosition.dy - 20,
      child: GestureDetector(
        onTap: () {
          if (mode == InteractionMode.removeEquipment) {
            ref.read(boardProvider.notifier).removeEquipment(equipment.id);
          }
        },
        onLongPress: mode == InteractionMode.move
            ? () {
                setState(() {
                  _rotationStartPoint = Offset.zero;
                  _initialRotation = equipment.rotation;
                });
              }
            : null,
        onPanStart: mode == InteractionMode.move ? _onPanStart : null,
        onPanUpdate: mode == InteractionMode.move ? _onPanUpdate : null,
        onPanEnd: mode == InteractionMode.move ? _onPanEnd : null,
        onDoubleTap: mode == InteractionMode.move ? _onDoubleTap : null,
        child: Transform.rotate(
          angle: equipment.rotation * math.pi / 180,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _dragOffset != null || _rotationStartPoint != null
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: _dragOffset != null || _rotationStartPoint != null
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: _buildEquipmentWidget(),
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentWidget() {
    switch (widget.equipment.type) {
      case EquipmentType.cone:
        return _buildCone();
      case EquipmentType.obstacle:
        return _buildObstacle();
      case EquipmentType.ladder:
        return _buildLadder();
      case EquipmentType.miniGoal:
        return _buildMiniGoal();
      case EquipmentType.pole:
        return _buildPole();
      case EquipmentType.yellowCard:
        return _buildCard(Colors.yellow);
      case EquipmentType.redCard:
        return _buildCard(Colors.red);
      case EquipmentType.topViewPlayer:
        return _buildTopViewPlayer();
      case EquipmentType.mannequin:
        return _buildMannequin();
    }
  }

  // ─── EQUIPMENT SHAPES ───

  Widget _buildCone() {
    return CustomPaint(
      size: const Size(40, 40),
      painter: _ConePainter(),
    );
  }

  Widget _buildObstacle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildLadder() {
    return CustomPaint(
      size: const Size(40, 40),
      painter: _LadderPainter(),
    );
  }

  Widget _buildMiniGoal() {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 3),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
      ),
    );
  }

  Widget _buildPole() {
    return Center(
      child: Container(
        width: 8,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red, Colors.red.shade800],
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 2,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Color color) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
        border: Border.all(color: Colors.black26, width: 1),
      ),
    );
  }

  Widget _buildTopViewPlayer() {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green.shade600,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildMannequin() {
    return CustomPaint(
      size: const Size(40, 40),
      painter: _MannequinPainter(),
    );
  }

  // ─── GESTURE HANDLERS ───

  void _onPanStart(DragStartDetails details) {
    if (_rotationStartPoint != null) {
      // Rotation mode
      setState(() {
        _rotationStartPoint = details.localPosition;
      });
    } else {
      // Movement mode
      setState(() {
        _dragOffset = Offset(
          widget.equipment.position.dx * widget.constraints.maxWidth,
          widget.equipment.position.dy * widget.constraints.maxHeight,
        );
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_rotationStartPoint != null) {
      // Rotation gesture - calcola angolo dal centro (360°)
      final center = const Offset(20, 20);
      final currentVector = details.localPosition - center;
      
      // Usa atan2 per calcolo angolo preciso in tutte le direzioni
      final angle = (math.atan2(currentVector.dy, currentVector.dx) * 180 / math.pi) + 90;
      
      // Normalizza l'angolo tra 0 e 360
      final normalizedAngle = angle % 360;
      
      ref.read(boardProvider.notifier).rotateEquipment(
        widget.equipment.id,
        normalizedAngle < 0 ? normalizedAngle + 360 : normalizedAngle,
      );
    } else if (_dragOffset != null) {
      // Movement gesture
      setState(() {
        _dragOffset = _dragOffset! + details.delta;
      });
      
      // Aggiorna posizione temporanea nel provider
      final normalizedX = (_dragOffset!.dx / widget.constraints.maxWidth).clamp(0.0, 1.0);
      final normalizedY = (_dragOffset!.dy / widget.constraints.maxHeight).clamp(0.0, 1.0);
      
      ref.read(boardProvider.notifier).moveEquipment(
        widget.equipment.id,
        Offset(normalizedX, normalizedY),
      );
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_rotationStartPoint != null) {
      // End rotation mode
      setState(() {
        _rotationStartPoint = null;
      });
    } else if (_dragOffset != null) {
      // Applica snap-to-grid se la griglia è attiva
      final showGrid = ref.read(showGridProvider);
      if (showGrid) {
        final normalizedX = (_dragOffset!.dx / widget.constraints.maxWidth).clamp(0.0, 1.0);
        final normalizedY = (_dragOffset!.dy / widget.constraints.maxHeight).clamp(0.0, 1.0);
        final snappedPosition = GridSnap.snapToGrid(Offset(normalizedX, normalizedY));
        ref.read(boardProvider.notifier).moveEquipment(widget.equipment.id, snappedPosition);
      }

      setState(() {
        _dragOffset = null;
      });
    }
  }

  void _onDoubleTap() {
    // Rimuovi equipment con doppio tap
    ref.read(boardProvider.notifier).removeEquipment(widget.equipment.id);
  }
}

// ─── CUSTOM PAINTERS ───

class _ConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Cono arancione
    final path = Path()
      ..moveTo(size.width / 2, 4)
      ..lineTo(size.width - 6, size.height - 4)
      ..lineTo(6, size.height - 4)
      ..close();

    // Gradiente
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.orange.shade300, Colors.orange.shade700],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);

    // Bordo
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.orange.shade900;
    canvas.drawPath(path, borderPaint);

    // Strisce bianche
    final stripePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;

    canvas.drawLine(
      Offset(size.width * 0.35, size.height * 0.5),
      Offset(size.width * 0.65, size.height * 0.5),
      stripePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.7),
      Offset(size.width * 0.75, size.height * 0.7),
      stripePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LadderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.yellow.shade700;

    // Lati verticali
    canvas.drawLine(Offset(8, 4), Offset(8, size.height - 4), paint);
    canvas.drawLine(Offset(size.width - 8, 4), Offset(size.width - 8, size.height - 4), paint);

    // Pioli orizzontali
    for (int i = 0; i < 4; i++) {
      final y = 8 + i * 9.0;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MannequinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.grey.shade600;

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.grey.shade800;

    // Testa
    canvas.drawCircle(Offset(size.width / 2, 10), 6, paint);
    canvas.drawCircle(Offset(size.width / 2, 10), 6, borderPaint);

    // Corpo
    final bodyPath = Path()
      ..moveTo(size.width / 2 - 8, 16)
      ..lineTo(size.width / 2 + 8, 16)
      ..lineTo(size.width / 2 + 6, size.height - 4)
      ..lineTo(size.width / 2 - 6, size.height - 4)
      ..close();

    canvas.drawPath(bodyPath, paint);
    canvas.drawPath(bodyPath, borderPaint);

    // Braccia
    canvas.drawLine(
      Offset(size.width / 2 - 8, 18),
      Offset(4, 24),
      borderPaint..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(size.width / 2 + 8, 18),
      Offset(size.width - 4, 24),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
