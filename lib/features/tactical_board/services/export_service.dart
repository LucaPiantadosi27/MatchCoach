import 'dart:typed_data';
import 'dart:ui' as ui;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/schemes_list_page.dart';

class ExportService {
  static Future<Uint8List?> exportAsImage(GlobalKey repaintBoundaryKey) async {
    try {
      debugPrint('📸 Starting capture...');
      
      final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      
      if (boundary == null) {
        debugPrint('❌ Boundary not found');
        return null;
      }

      debugPrint('✓ Boundary: ${boundary.size}');
      
      // Simple direct capture - no delays, no scheduling
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      debugPrint('✓ Image: ${image.width}x${image.height}');
      
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('❌ No bytes');
        return null;
      }

      final bytes = byteData.buffer.asUint8List();
      debugPrint('✅ ${(bytes.length / 1024).toStringAsFixed(1)} KB');
      return bytes;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return null;
    }
  }

  /// Captures the field, saves to Supabase and triggers a PNG download
  static Future<void> downloadSnapshot(
    GlobalKey repaintBoundaryKey,
    BuildContext context, {
    String fileName = 'schema',
    WidgetRef? ref,
  }) async {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Generando snapshot...'),
          ]),
          duration: Duration(seconds: 3),
        ),
      );
    }

    final imageBytes = await exportAsImage(repaintBoundaryKey);

    if (imageBytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore: impossibile catturare il campo'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Save to Supabase if user is logged in
    bool savedToCloud = false;
    if (ref != null) {
      // Save to Supabase
      final user = ref.read(userProvider).valueOrNull;
      if (user != null) {
        try {
          debugPrint('💾 Saving to Supabase...');
          await ref.read(snapshotRepositoryProvider).saveSnapshot(
            userId: user.id,
            name: fileName,
            imageBytes: imageBytes,
          );
          debugPrint('✅ Saved to Supabase');
          ref.invalidate(userSnapshotsProvider);
          savedToCloud = true;
        } catch (e) {
          debugPrint('❌ Supabase error: $e');
        }
      } else {
        debugPrint('⚠️ No user, skipping Supabase save');
      }
    }

    // Trigger browser download
    try {
      final blob = html.Blob([imageBytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', '${fileName}_${DateTime.now().millisecondsSinceEpoch}.png')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(savedToCloud ? 'Snapshot salvato e scaricato!' : 'Snapshot scaricato!'),
            ]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      debugPrint('ExportService: Download error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Returns a data URI usable as an <img src> from base64
  static String base64ToDataUri(String base64) =>
      'data:image/png;base64,$base64';
}
