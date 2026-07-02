import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';
import 'package:lavagna_tattica/features/video_analysis/data/repositories/video_analysis_repository.dart';
import 'package:lavagna_tattica/features/video_analysis/data/models/scout_statistics.dart';
import 'package:lavagna_tattica/features/video_analysis/presentation/video_analysis_page.dart';

class AnalysesArchivePage extends ConsumerWidget {
  const AnalysesArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Per semplicità usiamo un userId fisso o lo prendiamo da un provider se disponibile
    final user = ref.watch(userProvider).valueOrNull;
    debugPrint('ArchivePage: current user = ${user?.id}');
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Per favore, effettua il login per vedere lo storico.')),
      );
    }
    final userId = user.id;
    final repo = ref.watch(videoAnalysisRepositoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Archivio Analisi Tattiche', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.getUserAnalyses(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }
          if (snapshot.hasError) {
            debugPrint('ArchivePage: Query Error = ${snapshot.error}');
            return Center(child: Text('Errore: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }
          final analyses = snapshot.data ?? [];
          debugPrint('ArchivePage: count = ${analyses.length}');
          if (analyses.isEmpty) {
            return const Center(
              child: Text(
                'Nessuna analisi salvata.\nInizia subito ad analizzare un video!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: analyses.length,
            itemBuilder: (context, index) {
              final item = analyses[index];
              final date = DateTime.parse(item['created_at']);
              final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.cyanAccent,
                    child: Icon(Icons.analytics, color: Color(0xFF0F172A)),
                  ),
                  title: Text(
                    item['video_name'] ?? 'Analisi senza nome',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.cyanAccent),
                  onTap: () {
                    final stats = ScoutStatistics.fromJson(item['analysis_data']);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoAnalysisPage(
                          initialResults: stats,
                          initialAnalysisId: item['id'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
