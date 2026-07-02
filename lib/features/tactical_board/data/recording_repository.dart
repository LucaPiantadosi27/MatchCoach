import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/saved_recording.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/movement_keyframe.dart';

class RecordingRepository {
  final _supabase = Supabase.instance.client;

  Future<String> saveRecording({
    required String userId,
    required String name,
    required MovementRecording recording,
  }) async {
    final recordingId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final savedRecording = SavedRecording(
      id: recordingId,
      userId: userId,
      name: name,
      recording: recording,
      createdAt: DateTime.now(),
    );

    await _supabase
        .from('recordings')
        .insert({
          'id': savedRecording.id,
          'user_id': savedRecording.userId,
          'name': savedRecording.name,
          'data': savedRecording.recording.toJson(),
          'created_at': savedRecording.createdAt.toIso8601String(),
        });

    return recordingId;
  }

  Future<List<SavedRecording>> getUserRecordings(String userId) async {
    final response = await _supabase
        .from('recordings')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => SavedRecording(
              id: json['id'] as String,
              userId: json['user_id'] as String,
              name: json['name'] as String,
              recording: MovementRecording.fromJson(json['data'] as Map<String, dynamic>),
              createdAt: DateTime.parse(json['created_at'] as String),
            ))
        .toList();
  }

  Future<SavedRecording?> getRecording(String recordingId) async {
    try {
      final response = await _supabase
          .from('recordings')
          .select()
          .eq('id', recordingId)
          .single();

      return SavedRecording(
        id: response['id'] as String,
        userId: response['user_id'] as String,
        name: response['name'] as String,
        recording: MovementRecording.fromJson(response['data'] as Map<String, dynamic>),
        createdAt: DateTime.parse(response['created_at'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteRecording(String recordingId) async {
    await _supabase.from('recordings').delete().eq('id', recordingId);
  }

  Future<void> updateRecording({
    required String recordingId,
    String? name,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    
    if (updates.isNotEmpty) {
      await _supabase
          .from('recordings')
          .update(updates)
          .eq('id', recordingId);
    }
  }
}
