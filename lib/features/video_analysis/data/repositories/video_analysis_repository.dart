import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavagna_tattica/core/supabase_client.dart';
import 'package:lavagna_tattica/features/video_analysis/data/models/scout_statistics.dart';

final videoAnalysisRepositoryProvider = Provider<VideoAnalysisRepository>((ref) {
  return VideoAnalysisRepository();
});

class VideoAnalysisRepository {
  /// Salva l'analisi JSON su Supabase (non il video)
  Future<String> saveAnalysis({
    required String userId,
    required String videoName,
    required ScoutStatistics analysis,
    int promptTokens = 0,
    int completionTokens = 0,
    int totalTokens = 0,
    String? matchId,
  }) async {
    try {
      final data = {
        'user_id': userId,
        'video_name': videoName,
        'analysis_data': analysis.toJson(),
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      if (matchId != null) {
        data['match_id'] = matchId;
      }
      
      final response = await supabase.from('video_analyses').insert(data).select().single();

      return response['id'] as String;
    } catch (e) {
      throw Exception('Errore nel salvataggio dell\'analisi: $e');
    }
  }
  
  /// Associa un'analisi esistente a una partita
  Future<void> associateAnalysisToMatch(String analysisId, String matchId) async {
    try {
      await supabase.from('video_analyses').update({
        'match_id': matchId,
      }).eq('id', analysisId);
    } catch (e) {
      throw Exception('Errore nell\'associazione dell\'analisi alla partita: $e');
    }
  }

  /// Recupera tutte le analisi di un utente
  Future<List<Map<String, dynamic>>> getUserAnalyses(String userId) async {
    try {
      final response = await supabase
          .from('video_analyses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Errore nel recupero delle analisi: $e');
    }
  }

  /// Recupera una singola analisi
  Future<ScoutStatistics> getAnalysis(String analysisId) async {
    try {
      final response = await supabase
          .from('video_analyses')
          .select()
          .eq('id', analysisId)
          .single();

      return ScoutStatistics.fromJson(response['analysis_data']);
    } catch (e) {
      throw Exception('Errore nel recupero dell\'analisi: $e');
    }
  }

  /// Elimina un'analisi
  Future<void> deleteAnalysis(String analysisId) async {
    try {
      await supabase.from('video_analyses').delete().eq('id', analysisId);
    } catch (e) {
      throw Exception('Errore nell\'eliminazione dell\'analisi: $e');
    }
  }
}
