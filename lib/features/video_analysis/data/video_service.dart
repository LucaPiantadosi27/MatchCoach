import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lavagna_tattica/core/supabase_client.dart';

class VideoService {
  /// Returns the video as-is. FFmpeg compression removed (not supported on web).
  Future<dynamic> processVideo(XFile inputVideo) async {
    return inputVideo;
  }

  /// Uploads video to Supabase Storage 'videos' bucket.
  Future<String?> uploadVideo(dynamic videoFile, String userId) async {
    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final path = 'raw/$fileName';

      if (kIsWeb) {
        if (videoFile is! XFile) return null;
        
        // Try to ensure bucket exists (ignore error if already exists or no permission)
        try {
          await supabase.storage.createBucket('videos', const BucketOptions(public: true));
        } catch (_) {}

        final bytes = await videoFile.readAsBytes();
        await supabase.storage.from('videos').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: 'video/mp4'),
            );
      } else {
        if (videoFile is! File) return null;
        await supabase.storage.from('videos').upload(
              path,
              videoFile,
              fileOptions: FileOptions(contentType: 'video/mp4'),
            );
      }

      return supabase.storage.from('videos').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading video to Supabase: $e');
      return null;
    }
  }
}
