import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lavagna_tattica/features/tactical_board/data/models/drawing_path.dart';

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;
  final DrawingPath? currentPath;

  const DrawingPainter({required this.paths, this.currentPath});

  @override
  void paint(Canvas canvas, Size size) {
    for (final path in [...paths, if (currentPath != null) currentPath!]) {
      if (path.points.length < 2) continue;
      _drawPath(canvas, size, path);
    }
  }

  void _drawPath(Canvas canvas, Size size, DrawingPath path) {
    final paint = Paint()
      ..color = path.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = path.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Convert normalized points to pixel points
    final pixelPoints = path.points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    switch (path.lineStyle) {
      case LineStyle.solid:
        _drawSolid(canvas, pixelPoints, paint);
        break;
      case LineStyle.dashed:
        _drawDashed(canvas, pixelPoints, paint, 10.0, 5.0);
        break;
      case LineStyle.dotted:
        _drawDotted(canvas, pixelPoints, paint);
        break;
      case LineStyle.dashDot:
        _drawDashDot(canvas, pixelPoints, paint);
        break;
      case LineStyle.dashDotDot:
        _drawDashDotDot(canvas, pixelPoints, paint);
        break;
      case LineStyle.wavy:
        _drawWavy(canvas, pixelPoints, paint);
        break;
      case LineStyle.arrow:
        _drawSolid(canvas, pixelPoints, paint);
        _drawArrowHead(canvas, pixelPoints, paint, end: true, start: false);
        break;
      case LineStyle.doubleArrow:
        _drawSolid(canvas, pixelPoints, paint);
        _drawArrowHead(canvas, pixelPoints, paint, end: true, start: true);
        break;
      case LineStyle.curved:
        _drawCurved(canvas, pixelPoints, paint);
        break;
      case LineStyle.zigzag:
        _drawZigzag(canvas, pixelPoints, paint);
        break;
      case LineStyle.thick:
        paint.strokeWidth = path.strokeWidth * 2.5;
        _drawSolid(canvas, pixelPoints, paint);
        break;
      case LineStyle.highlighter:
        paint.color = path.color.withValues(alpha: 0.35);
        paint.strokeWidth = path.strokeWidth * 4;
        paint.strokeCap = StrokeCap.butt;
        _drawSolid(canvas, pixelPoints, paint);
        break;
    }

    // Draw arrow if hasArrow is true (independent of line style)
    if (path.hasArrow && path.lineStyle != LineStyle.arrow && path.lineStyle != LineStyle.doubleArrow) {
      final arrowPaint = Paint()
        ..color = path.color
        ..style = PaintingStyle.fill;
      _drawArrowHead(canvas, pixelPoints, arrowPaint, end: true, start: false);
    }
  }

  // ─── SOLID LINE ───
  void _drawSolid(Canvas canvas, List<Offset> points, Paint paint) {
    final dartPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      dartPath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(dartPath, paint);
  }

  // ─── DASHED LINE ───
  void _drawDashed(Canvas canvas, List<Offset> points, Paint paint, double dashWidth, double dashSpace) {
    final dartPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      dartPath.lineTo(points[i].dx, points[i].dy);
    }

    double distance = 0.0;
    for (final metric in dartPath.computeMetrics()) {
      while (distance < metric.length) {
        final end = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }
  }

  // ─── DOTTED LINE ───
  void _drawDotted(Canvas canvas, List<Offset> points, Paint paint) {
    final dartPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      dartPath.lineTo(points[i].dx, points[i].dy);
    }

    final dotPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    final dotRadius = paint.strokeWidth * 0.6;
    const dotSpacing = 8.0;

    for (final metric in dartPath.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, dotRadius, dotPaint);
        }
        distance += dotSpacing;
      }
    }
  }

  // ─── DASH-DOT LINE (— • — • —) ───
  void _drawDashDot(Canvas canvas, List<Offset> points, Paint paint) {
    final dartPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      dartPath.lineTo(points[i].dx, points[i].dy);
    }

    final dotPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    const dashLen = 12.0;
    const gap = 4.0;
    const dotRadius = 1.5;

    for (final metric in dartPath.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        // Draw dash
        final dashEnd = math.min(distance + dashLen, metric.length);
        canvas.drawPath(metric.extractPath(distance, dashEnd), paint);
        distance += dashLen + gap;

        // Draw dot
        if (distance < metric.length) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            canvas.drawCircle(tangent.position, dotRadius, dotPaint);
          }
          distance += dotRadius * 2 + gap;
        }
      }
    }
  }

  // ─── DASH-DOT-DOT LINE (— •• — ••) ───
  void _drawDashDotDot(Canvas canvas, List<Offset> points, Paint paint) {
    final dartPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      dartPath.lineTo(points[i].dx, points[i].dy);
    }

    final dotPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    const dashLen = 12.0;
    const gap = 4.0;
    const dotRadius = 1.5;
    const dotGap = 3.0;

    for (final metric in dartPath.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        // Draw dash
        final dashEnd = math.min(distance + dashLen, metric.length);
        canvas.drawPath(metric.extractPath(distance, dashEnd), paint);
        distance += dashLen + gap;

        // Draw first dot
        if (distance < metric.length) {
          final t1 = metric.getTangentForOffset(distance);
          if (t1 != null) canvas.drawCircle(t1.position, dotRadius, dotPaint);
          distance += dotRadius * 2 + dotGap;
        }

        // Draw second dot
        if (distance < metric.length) {
          final t2 = metric.getTangentForOffset(distance);
          if (t2 != null) canvas.drawCircle(t2.position, dotRadius, dotPaint);
          distance += dotRadius * 2 + gap;
        }
      }
    }
  }

  // ─── WAVY LINE (∿∿∿∿∿) ───
  void _drawWavy(Canvas canvas, List<Offset> points, Paint paint) {
    final dartPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      dartPath.lineTo(points[i].dx, points[i].dy);
    }

    const waveLength = 12.0;
    const waveAmplitude = 5.0;

    final wavyPath = Path();
    bool first = true;

    for (final metric in dartPath.computeMetrics()) {
      double distance = 0.0;

      while (distance < metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null) break;

        // Perpendicular offset for waveform
        final normal = Offset(
            tangent.angle.isNaN ? 0 : -math.sin(tangent.angle),
            tangent.angle.isNaN ? 0 : math.cos(tangent.angle));
        final wave = math.sin(distance / waveLength * math.pi * 2) * waveAmplitude;
        final point = tangent.position + normal * wave;

        if (first) {
          wavyPath.moveTo(point.dx, point.dy);
          first = false;
        } else {
          wavyPath.lineTo(point.dx, point.dy);
        }
        distance += 2.0;
      }
    }

    canvas.drawPath(wavyPath, paint);
  }

  // ─── CURVED LINE (smooth bezier) ───
  void _drawCurved(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;

    final curvePath = Path()..moveTo(points[0].dx, points[0].dy);

    if (points.length == 2) {
      curvePath.lineTo(points[1].dx, points[1].dy);
    } else {
      // Use quadratic bezier for smoothing
      for (int i = 0; i < points.length - 1; i++) {
        final current = points[i];
        final next = points[i + 1];
        final midX = (current.dx + next.dx) / 2;
        final midY = (current.dy + next.dy) / 2;

        if (i == 0) {
          curvePath.quadraticBezierTo(current.dx, current.dy, midX, midY);
        } else {
          curvePath.quadraticBezierTo(current.dx, current.dy, midX, midY);
        }
      }
      // Final segment
      final last = points.last;
      curvePath.lineTo(last.dx, last.dy);
    }

    canvas.drawPath(curvePath, paint);
  }

  // ─── ZIGZAG LINE (/\/\/\/) ───
  void _drawZigzag(Canvas canvas, List<Offset> points, Paint paint) {
    final dartPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      dartPath.lineTo(points[i].dx, points[i].dy);
    }

    const zigLength = 8.0;
    const zigAmplitude = 5.0;

    final zigzagPath = Path();
    bool first = true;
    int zigDirection = 1;

    for (final metric in dartPath.computeMetrics()) {
      double distance = 0.0;

      while (distance < metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null) break;

        final normal = Offset(
          -math.sin(tangent.angle),
          math.cos(tangent.angle),
        );
        final point = tangent.position + normal * (zigAmplitude * zigDirection);

        if (first) {
          zigzagPath.moveTo(tangent.position.dx, tangent.position.dy);
          first = false;
        }
        zigzagPath.lineTo(point.dx, point.dy);

        zigDirection *= -1;
        distance += zigLength;
      }
    }

    canvas.drawPath(zigzagPath, paint);
  }

  // ─── ARROW HEAD ───
  void _drawArrowHead(Canvas canvas, List<Offset> points, Paint paint, {required bool end, required bool start}) {
    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    const arrowSize = 12.0;

    if (end && points.length >= 2) {
      final tip = points.last;
      final prev = points[points.length - 2];
      final angle = math.atan2(tip.dy - prev.dy, tip.dx - prev.dx);

      final arrowPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          tip.dx - arrowSize * math.cos(angle - math.pi / 6),
          tip.dy - arrowSize * math.sin(angle - math.pi / 6),
        )
        ..lineTo(
          tip.dx - arrowSize * math.cos(angle + math.pi / 6),
          tip.dy - arrowSize * math.sin(angle + math.pi / 6),
        )
        ..close();

      canvas.drawPath(arrowPath, arrowPaint);
    }

    if (start && points.length >= 2) {
      final tip = points.first;
      final next = points[1];
      final angle = math.atan2(tip.dy - next.dy, tip.dx - next.dx);

      final arrowPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          tip.dx - arrowSize * math.cos(angle - math.pi / 6),
          tip.dy - arrowSize * math.sin(angle - math.pi / 6),
        )
        ..lineTo(
          tip.dx - arrowSize * math.cos(angle + math.pi / 6),
          tip.dy - arrowSize * math.sin(angle + math.pi / 6),
        )
        ..close();

      canvas.drawPath(arrowPath, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
