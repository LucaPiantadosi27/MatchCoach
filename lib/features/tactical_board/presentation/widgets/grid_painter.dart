import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final bool showGrid;
  final int horizontalDivisions;
  final int verticalDivisions;
  final Color gridColor;

  const GridPainter({
    this.showGrid = true,
    this.horizontalDivisions = 20,
    this.verticalDivisions = 12,
    this.gridColor = const Color(0x30FFFFFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showGrid) return;

    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Linee verticali
    final cellWidth = size.width / horizontalDivisions;
    for (int i = 1; i < horizontalDivisions; i++) {
      final x = i * cellWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Linee orizzontali
    final cellHeight = size.height / verticalDivisions;
    for (int i = 1; i < verticalDivisions; i++) {
      final y = i * cellHeight;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Linee centrali più evidenti
    final centerPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Linea centrale verticale
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      centerPaint,
    );

    // Linea centrale orizzontale
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.showGrid != showGrid ||
        oldDelegate.horizontalDivisions != horizontalDivisions ||
        oldDelegate.verticalDivisions != verticalDivisions ||
        oldDelegate.gridColor != gridColor;
  }
}

/// Utility per snap-to-grid
class GridSnap {
  static const int defaultHorizontalDivisions = 20;
  static const int defaultVerticalDivisions = 12;

  /// Allinea una posizione normalizzata (0.0-1.0) alla griglia più vicina
  static Offset snapToGrid(
    Offset position, {
    int horizontalDivisions = defaultHorizontalDivisions,
    int verticalDivisions = defaultVerticalDivisions,
  }) {
    final cellWidth = 1.0 / horizontalDivisions;
    final cellHeight = 1.0 / verticalDivisions;

    final snappedX = (position.dx / cellWidth).round() * cellWidth;
    final snappedY = (position.dy / cellHeight).round() * cellHeight;

    return Offset(
      snappedX.clamp(0.0, 1.0),
      snappedY.clamp(0.0, 1.0),
    );
  }

  /// Allinea alla griglia solo se la distanza è minore di una soglia
  static Offset snapToGridIfClose(
    Offset position, {
    int horizontalDivisions = defaultHorizontalDivisions,
    int verticalDivisions = defaultVerticalDivisions,
    double threshold = 0.03,
  }) {
    final snapped = snapToGrid(
      position,
      horizontalDivisions: horizontalDivisions,
      verticalDivisions: verticalDivisions,
    );

    final distance = (position - snapped).distance;
    if (distance < threshold) {
      return snapped;
    }
    return position;
  }
}
