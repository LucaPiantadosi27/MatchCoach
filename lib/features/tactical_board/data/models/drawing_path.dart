import 'package:flutter/material.dart';

/// Stili di linea disponibili per il disegno tattico
enum LineStyle {
  solid,         // ——————————
  dashed,        // — — — — —
  dotted,        // • • • • •
  dashDot,       // — • — • —
  dashDotDot,    // — •• — ••
  wavy,          // ∿∿∿∿∿∿∿
  arrow,         // ———————→
  doubleArrow,   // ←———————→
  curved,        // smooth bezier
  zigzag,        // /\/\/\/\/
  thick,         // ━━━━━━━━
  highlighter,   // semi-transparent wide
}

class DrawingPath {
  final List<Offset> points; // Relative points 0.0 to 1.0
  final LineStyle lineStyle;
  final Color color;
  final double strokeWidth;
  final bool hasArrow;

  const DrawingPath({
    required this.points,
    this.lineStyle = LineStyle.solid,
    this.color = Colors.white,
    this.strokeWidth = 3.0,
    this.hasArrow = false,
  });

  /// Legacy compatibility: check if this is a dashed style
  bool get isDashed => lineStyle == LineStyle.dashed ||
      lineStyle == LineStyle.dashDot ||
      lineStyle == LineStyle.dashDotDot;

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'lineStyle': lineStyle.name,
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
      'hasArrow': hasArrow,
    };
  }

  factory DrawingPath.fromJson(Map<String, dynamic> json) {
    // Backward compatibility with old format
    LineStyle style = LineStyle.solid;
    if (json.containsKey('lineStyle')) {
      try {
        style = LineStyle.values.byName(json['lineStyle'] as String);
      } catch (_) {
        style = LineStyle.solid;
      }
    } else if (json.containsKey('isDashed') && json['isDashed'] == true) {
      style = LineStyle.dashed;
    }

    return DrawingPath(
      points: (json['points'] as List)
          .map((p) => Offset(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ))
          .toList(),
      lineStyle: style,
      color: Color(json['color'] as int? ?? Colors.white.toARGB32()),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      hasArrow: json['hasArrow'] as bool? ?? false,
    );
  }
}
