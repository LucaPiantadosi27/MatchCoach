import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:lavagna_tattica/features/tactical_board/data/models/field_background.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/board_provider.dart';

/// Widget wrapper: renders background (solid color or image) + field lines on top
class FieldBackground$View extends StatefulWidget {
  final FieldBackground background;
  final FieldViewMode viewMode;

  const FieldBackground$View({
    super.key,
    required this.background,
    required this.viewMode,
  });

  @override
  State<FieldBackground$View> createState() => _FieldBackground$ViewState();
}

class _FieldBackground$ViewState extends State<FieldBackground$View> {
  static const _kParquetViewType = 'field-parquet-bg';
  static bool _parquetRegistered = false;

  @override
  void initState() {
    super.initState();
    _registerParquetView();
  }

  void _registerParquetView() {
    if (_parquetRegistered) return;
    _parquetRegistered = true;
    // Flutter Web serves assets at 'assets/' prefix in debug mode
    const assetUrl = 'assets/images/parquet-chiaro.jpg';
    debugPrint('🪵 Registering parquet HtmlElementView with url: $assetUrl');
    ui_web.platformViewRegistry.registerViewFactory(
      _kParquetViewType,
      (int _) {
        final div = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundImage = 'url($assetUrl)'
          ..style.backgroundSize = 'auto'
          ..style.backgroundRepeat = 'repeat';
        return div;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isParquet = widget.background.type == FieldBackgroundType.parquetLight;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (isParquet)
          const HtmlElementView(viewType: _kParquetViewType)
        else
          Container(color: widget.background.solidColor),
        CustomPaint(
          painter: FieldPainter(
            background: widget.background,
            viewMode: widget.viewMode,
          ),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

class FieldPainter extends CustomPainter {
  final FieldBackground background;
  final ui.Image? backgroundImage;
  final FieldViewMode viewMode;

  const FieldPainter({
    required this.background,
    this.backgroundImage,
    this.viewMode = FieldViewMode.fullField,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background based on type
    _drawBackground(canvas, size);

    // Disegna il campo in base alla modalità
    switch (viewMode) {
      case FieldViewMode.fullField:
        _drawFullField(canvas, size);
        break;
      case FieldViewMode.halfFieldLeft:
        _drawHalfFieldLeft(canvas, size);
        break;
      case FieldViewMode.halfFieldRight:
        _drawHalfFieldRight(canvas, size);
        break;
    }
  }

  void _drawFullField(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Applica un margine interno per lasciare un po' di spazio attorno alle linee del campo
    final double padding = math.max(4.0, math.min(size.width, size.height) * 0.01);
    final double scaleX = (size.width - 2 * padding) / size.width;
    final double scaleY = (size.height - 2 * padding) / size.height;

    canvas.save();
    canvas.translate(padding, padding);
    canvas.scale(scaleX, scaleY);

    final rect = Offset.zero & size;

    // External Border
    canvas.drawRect(rect, paint);

    // Center Line
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Center Circle (enlarged)
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 60, paint);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2,
      Paint()..color = Colors.white,
    );

    // FUTSAL: Semicerchi da 6m (non rettangoli!)
    final double penaltyArcRadius = size.height * 0.35; // Raggio 6m
    
    // Left Penalty Arc (semicerchio da 6m)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, size.height / 2), radius: penaltyArcRadius),
      -math.pi / 2, // -90 gradi (alto)
      math.pi, // 180 gradi (semicerchio)
      false,
      paint,
    );

    // Right Penalty Arc (semicerchio da 6m)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: penaltyArcRadius),
      math.pi / 2, // 90 gradi (basso)
      math.pi, // 180 gradi (semicerchio)
      false,
      paint,
    );

    // Porte (3m x 2m) - leggermente oltre la linea di fondo (fuori dal campo)
    // goalDepth = quanto la porta "esce" fuori dal campo (ridotto per non sconfinare su sidebar)
    final double goalDepth = size.width * 0.010;
    final double goalHeight = size.height * 0.15;

    // Left Goal (rettangolo bianco semitrasparente)
    canvas.drawRect(
      Rect.fromLTWH(-goalDepth, size.height * 0.425, goalDepth, goalHeight),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    // Bordo porta sinistra bianco
    canvas.drawRect(
      Rect.fromLTWH(-goalDepth, size.height * 0.425, goalDepth, goalHeight),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Right Goal (rettangolo bianco semitrasparente)
    canvas.drawRect(
      Rect.fromLTWH(size.width, size.height * 0.425, goalDepth, goalHeight),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    // Bordo porta destra bianco
    canvas.drawRect(
      Rect.fromLTWH(size.width, size.height * 0.425, goalDepth, goalHeight),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Penalty Spot (6m dal centro porta)
    final double penaltySpotDistance = size.width * 0.15;
    canvas.drawCircle(
        Offset(penaltySpotDistance, size.height / 2), 3, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(size.width - penaltySpotDistance, size.height / 2), 3, Paint()..color = Colors.white);

    // Second Penalty Spot (10m dal centro porta)
    final double secondPenaltyDistance = size.width * 0.25;
    canvas.drawCircle(
        Offset(secondPenaltyDistance, size.height / 2), 3, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(size.width - secondPenaltyDistance, size.height / 2), 3, Paint()..color = Colors.white);

    // Corner Arcs (quarti di cerchio agli angoli - 25cm radius)
    final double cornerRadius = 25.0;
    
    // Top-left corner
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, 0), radius: cornerRadius),
      0,
      math.pi / 2,
      false,
      paint,
    );

    // Top-right corner
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width, 0), radius: cornerRadius),
      math.pi / 2,
      math.pi / 2,
      false,
      paint,
    );

    // Bottom-left corner
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, size.height), radius: cornerRadius),
      -math.pi / 2,
      math.pi / 2,
      false,
      paint,
    );

    // Bottom-right corner
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width, size.height), radius: cornerRadius),
      math.pi,
      math.pi / 2,
      false,
      paint,
    );
    // Ripristina trasformazioni
    canvas.restore();
  }

  /// Disegna metà campo sinistra (ingrandita)
  void _drawHalfFieldLeft(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final double padding = math.max(16.0, math.min(size.width, size.height) * 0.03);
    
    canvas.save();
    canvas.translate(padding, padding);
    
    final fieldWidth = size.width - 2 * padding;
    final fieldHeight = size.height - 2 * padding;

    // External Border (metà campo)
    canvas.drawRect(Rect.fromLTWH(0, 0, fieldWidth, fieldHeight), paint);

    // Linea di metà campo (a destra)
    canvas.drawLine(
      Offset(fieldWidth, 0),
      Offset(fieldWidth, fieldHeight),
      paint,
    );

    // Semicerchio centrale (tagliato a metà)
    final centerRadius = fieldHeight * 0.15;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(fieldWidth, fieldHeight / 2), radius: centerRadius),
      math.pi / 2,
      math.pi,
      false,
      paint,
    );

    // Area di rigore ingrandita (semicerchio 6m)
    final penaltyArcRadius = fieldHeight * 0.45;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, fieldHeight / 2), radius: penaltyArcRadius),
      -math.pi / 2,
      math.pi,
      false,
      paint,
    );

    // Porta sinistra (leggermente fuori dal campo)
    final goalDepth = fieldWidth * 0.015;
    final goalHeight = fieldHeight * 0.2;
    canvas.drawRect(
      Rect.fromLTWH(-goalDepth, fieldHeight * 0.4, goalDepth, goalHeight),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    canvas.drawRect(
      Rect.fromLTWH(-goalDepth, fieldHeight * 0.4, goalDepth, goalHeight),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Penalty spots
    final penaltySpot1 = fieldWidth * 0.2;
    final penaltySpot2 = fieldWidth * 0.35;
    canvas.drawCircle(Offset(penaltySpot1, fieldHeight / 2), 4, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(penaltySpot2, fieldHeight / 2), 4, Paint()..color = Colors.white);

    // Corner arcs
    final cornerRadius = 30.0;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, 0), radius: cornerRadius),
      0, math.pi / 2, false, paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, fieldHeight), radius: cornerRadius),
      -math.pi / 2, math.pi / 2, false, paint,
    );

    canvas.restore();
  }

  /// Disegna metà campo destra (ingrandita)
  void _drawHalfFieldRight(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final double padding = math.max(16.0, math.min(size.width, size.height) * 0.03);
    
    canvas.save();
    canvas.translate(padding, padding);
    
    final fieldWidth = size.width - 2 * padding;
    final fieldHeight = size.height - 2 * padding;

    // External Border (metà campo)
    canvas.drawRect(Rect.fromLTWH(0, 0, fieldWidth, fieldHeight), paint);

    // Linea di metà campo (a sinistra)
    canvas.drawLine(
      Offset(0, 0),
      Offset(0, fieldHeight),
      paint,
    );

    // Semicerchio centrale (tagliato a metà)
    final centerRadius = fieldHeight * 0.15;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, fieldHeight / 2), radius: centerRadius),
      -math.pi / 2,
      math.pi,
      false,
      paint,
    );

    // Area di rigore ingrandita (semicerchio 6m)
    final penaltyArcRadius = fieldHeight * 0.45;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(fieldWidth, fieldHeight / 2), radius: penaltyArcRadius),
      math.pi / 2,
      math.pi,
      false,
      paint,
    );

    // Porta destra (leggermente fuori dal campo)
    final goalDepth = fieldWidth * 0.015;
    final goalHeight = fieldHeight * 0.2;
    canvas.drawRect(
      Rect.fromLTWH(fieldWidth, fieldHeight * 0.4, goalDepth, goalHeight),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    canvas.drawRect(
      Rect.fromLTWH(fieldWidth, fieldHeight * 0.4, goalDepth, goalHeight),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Penalty spots
    final penaltySpot1 = fieldWidth * 0.8;
    final penaltySpot2 = fieldWidth * 0.65;
    canvas.drawCircle(Offset(penaltySpot1, fieldHeight / 2), 4, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(penaltySpot2, fieldHeight / 2), 4, Paint()..color = Colors.white);

    // Corner arcs
    final cornerRadius = 30.0;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(fieldWidth, 0), radius: cornerRadius),
      math.pi / 2, math.pi / 2, false, paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(fieldWidth, fieldHeight), radius: cornerRadius),
      math.pi, math.pi / 2, false, paint,
    );

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Size size) {
    switch (background.type) {
      case FieldBackgroundType.green:
      case FieldBackgroundType.blue:
      case FieldBackgroundType.lightBlue:
      case FieldBackgroundType.grey:
        // Solid color background
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = background.solidColor!,
        );
        break;

      case FieldBackgroundType.parquetLight:
        // HtmlElementView handles the image background
        break;
    }
  }

  // ignore: unused_element
  void _drawTiledImage(Canvas canvas, Size size, ui.Image image) {
    final paint = Paint()..filterQuality = FilterQuality.medium;
    
    // Dimensioni originali dell'immagine
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    
    // Se l'immagine è troppo piccola, scala per avere tile di almeno 200px
    double tileWidth = imageWidth;
    double tileHeight = imageHeight;
    
    if (imageWidth < 200 || imageHeight < 200) {
      final scale = 200.0 / math.min(imageWidth, imageHeight);
      tileWidth = imageWidth * scale;
      tileHeight = imageHeight * scale;
    }
    
    // Ripeti l'immagine mantenendo le proporzioni
    for (double y = 0; y < size.height; y += tileHeight) {
      for (double x = 0; x < size.width; x += tileWidth) {
        final destRect = Rect.fromLTWH(x, y, tileWidth, tileHeight);
        final srcRect = Rect.fromLTWH(0, 0, imageWidth, imageHeight);
        canvas.drawImageRect(image, srcRect, destRect, paint);
      }
    }
  }

  // ignore: unused_element
  void _drawGeneratedParquet(Canvas canvas, Size size, bool isLight) {
    // Base parquet color
    final baseColor = isLight ? const Color(0xFFD4A574) : const Color(0xFF8B6F47);
    
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = baseColor,
    );

    // Disegna listelli di parquet
    final plankWidth = 80.0;
    final plankHeight = 12.0;
    final random = math.Random(42);

    for (double y = 0; y < size.height; y += plankHeight) {
      for (double x = 0; x < size.width; x += plankWidth) {
        final variation = random.nextDouble() * 0.15 - 0.075;
        final plankColor = Color.lerp(
          baseColor,
          baseColor.withValues(alpha: 0.8),
          variation.abs(),
        )!;

        canvas.drawRect(
          Rect.fromLTWH(x, y, plankWidth - 1, plankHeight - 1),
          Paint()..color = plankColor,
        );

        final grainPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.3)
          ..strokeWidth = 0.5;

        for (int i = 0; i < 3; i++) {
          final grainY = y + plankHeight * (i / 3);
          canvas.drawLine(
            Offset(x, grainY),
            Offset(x + plankWidth - 1, grainY),
            grainPaint,
          );
        }
      }
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant FieldPainter oldDelegate) {
    return oldDelegate.background.type != background.type ||
           oldDelegate.backgroundImage != backgroundImage ||
           oldDelegate.viewMode != viewMode;
  }
}
