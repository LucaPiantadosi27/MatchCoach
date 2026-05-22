import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavagna_tattica/features/video_analysis/data/repositories/video_analysis_repository.dart';

/// Provider per le analisi video associate a una partita specifica
final matchAnalysesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, matchId) async {
  final repository = ref.read(videoAnalysisRepositoryProvider);
  return await repository.getMatchAnalyses(matchId);
});
