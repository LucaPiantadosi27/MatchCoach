import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';
import 'package:lavagna_tattica/features/matches/data/models/match_model.dart';
import 'package:lavagna_tattica/features/matches/data/models/match_video_model.dart';
import 'package:lavagna_tattica/features/matches/data/repositories/matches_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:lavagna_tattica/features/matches/providers/matches_providers.dart';
import 'package:lavagna_tattica/features/video_analysis/data/models/scout_statistics.dart';
import 'package:lavagna_tattica/features/video_analysis/presentation/video_analysis_page.dart';
import 'package:lavagna_tattica/features/video_analysis/providers/video_analysis_providers.dart';
import 'package:lavagna_tattica/features/video_analysis/data/repositories/video_analysis_repository.dart';

class MatchDetailPage extends ConsumerWidget {
  final String matchId;
  const MatchDetailPage({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(matchVideosProvider(matchId));
    final analysesAsync = ref.watch(matchAnalysesProvider(matchId));
    final matchAsync = ref.watch(_matchProvider(matchId));

    return matchAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))),
      error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
      data: (match) {
        if (match == null) return const Scaffold(body: Center(child: Text('Partita non trovata')));
        return analysesAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))),
          error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
          data: (analyses) {
            return videosAsync.when(
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))),
              error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
              data: (videos) {
            return Scaffold(
                backgroundColor: AppTheme.surfaceColor,
                appBar: AppBar(
                  title: Text(match.displayTitle),
                  backgroundColor: AppTheme.cardColor,
                  surfaceTintColor: Colors.transparent,
                  actions: [
                    if (match.team1Color != null && match.team2Color != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Row(
                          children: [
                            _ColorChip(color: match.team1Color!, label: match.homeTeam),
                            const SizedBox(width: 8),
                            _ColorChip(color: match.team2Color!, label: match.awayTeam),
                          ],
                        ),
                      ),
                  ],
                ),
                body: Column(
                      children: [
                        _MatchInfoBar(match: match),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Row(
                            children: [
                              const Text('CLIP VIDEO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.4)),
                              const Spacer(),
                              _UploadButton(match: match, onUploaded: () => ref.invalidate(matchVideosProvider(matchId))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: videos.isEmpty && analyses.isEmpty
                              ? _EmptyClips(match: match, onUploaded: () => ref.invalidate(matchVideosProvider(matchId)))
                              : ListView(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  children: [
                                    ...analyses.map((analysis) => _AnalysisRow(
                                      key: ValueKey(analysis['id']),
                                      analysis: analysis,
                                      match: match,
                                      onDeleted: () {
                                        ref.invalidate(matchAnalysesProvider(matchId));
                                      },
                                    )),
                                    ...videos.map((video) => _ClipRow(
                                      key: ValueKey(video.id),
                                      video: video,
                                      index: videos.indexOf(video),
                                      match: match,
                                      onDeleted: () => ref.invalidate(matchVideosProvider(matchId)),
                                      onAnalyzed: () => ref.invalidate(matchVideosProvider(matchId)),
                                    )),
                                  ],
                                ),
                        ),
                  ],
                ),
              );
              },
            );
          },
        );
      },
    );
  }
}

// ── Provider for single match ─────────────────────────────────────
final _matchProvider = FutureProvider.autoDispose.family<MatchModel?, String>((ref, matchId) async {
  final matches = await ref.read(matchesRepositoryProvider).getMatches();
  try {
    return matches.firstWhere((m) => m.id == matchId);
  } catch (_) {
    return null;
  }
});

// ── Match info bar ────────────────────────────────────────────────
class _MatchInfoBar extends StatelessWidget {
  final MatchModel match;
  const _MatchInfoBar({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(bottom: BorderSide(color: AppTheme.sidebarBorderColor)),
      ),
      child: Row(
        children: [
          if (match.matchDate != null) ...[
            const Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(DateFormat('dd/MM/yyyy').format(match.matchDate!), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(width: 16),
          ],
          if (match.venue != null) ...[
            const Icon(Icons.place_outlined, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(match.venue!, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
          const Spacer(),
          if (match.team1Color == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.palette_outlined, size: 12, color: Color(0xFFF59E0B)),
                  SizedBox(width: 5),
                  Text('Colori non impostati', style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Upload button ─────────────────────────────────────────────────
class _UploadButton extends ConsumerWidget {
  final MatchModel match;
  final VoidCallback onUploaded;
  const _UploadButton({required this.match, required this.onUploaded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppTheme.accentGreenDim,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _pickAndUpload(context, ref),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 14, color: Colors.white),
              SizedBox(width: 6),
              Text('Aggiungi clip', style: TextStyle(fontSize: 12, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  void _pickAndUpload(BuildContext context, WidgetRef ref) {
    final input = html.FileUploadInputElement()..accept = 'video/*';
    input.click();
    input.onChange.listen((_) async {
      final file = input.files?.first;
      if (file == null) return;

      final userId = ref.read(userProvider).valueOrNull?.id ?? '';
      final videos = await ref.read(matchesRepositoryProvider).getMatchVideos(match.id);
      final nextOrder = videos.length;

      final newVideo = MatchVideoModel(
        id: '',
        matchId: match.id,
        userId: userId,
        sequenceOrder: nextOrder,
        videoName: file.name,
        analysisStatus: AnalysisStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(matchesRepositoryProvider).createMatchVideo(newVideo);
      onUploaded();
    });
  }
}

// ── Clip row ──────────────────────────────────────────────────────
class _ClipRow extends ConsumerStatefulWidget {
  final MatchVideoModel video;
  final int index;
  final MatchModel match;
  final VoidCallback onDeleted;
  final VoidCallback onAnalyzed;
  const _ClipRow({super.key, required this.video, required this.index, required this.match, required this.onDeleted, required this.onAnalyzed});

  @override
  ConsumerState<_ClipRow> createState() => _ClipRowState();
}

class _ClipRowState extends ConsumerState<_ClipRow> {
  // ignore: unused_field
  bool _isCancelled = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(widget.video.analysisStatus);
    final statusLabel = _statusLabel(widget.video.analysisStatus);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.video.isAnalyzed 
            ? AppTheme.accentGreen.withValues(alpha: 0.3) 
            : AppTheme.sidebarBorderColor,
          width: widget.video.isAnalyzed ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: widget.index,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 20,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Order badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accentGreen.withValues(alpha: 0.2), AppTheme.accentGreen.withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Text(
                '${widget.index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentGreen,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.video_library_rounded, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.video.videoName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.video.isAnalyzed) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.token_outlined, size: 12, color: AppTheme.textMuted.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          '${_fmtN(widget.video.totalTokens)} tok',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Actions - wrapped in Row to prevent overflow
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.video.isProcessing) ...[
                  // Stop button + loader during processing
                  GestureDetector(
                    onLongPress: _onForceReset,
                    child: IconButton(
                      icon: const Icon(Icons.stop_rounded, color: AppTheme.errorColor),
                      tooltip: 'Ferma analisi (tieni premuto per reset forzato)',
                      onPressed: _onStopAnalysis,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.accentGreen),
                    ),
                  ),
                ] else if (widget.video.analysisStatus == AnalysisStatus.error || widget.video.analysisStatus == AnalysisStatus.cancelled) ...[
                  // Go to chat if analysis exists, otherwise go to video page
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.accentGreen),
                    tooltip: 'Vai alla chat',
                    onPressed: () => _navigateToChat(context),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted),
                    tooltip: 'Elimina',
                    onPressed: () => _onDelete(context, ref),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ] else ...[
                  // Normal actions (pending or done)
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.accentGreen),
                    tooltip: 'Vai alla chat',
                    onPressed: () => _navigateToChat(context),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted),
                    tooltip: 'Elimina',
                    onPressed: () => _onDelete(context, ref),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context) {
    if (widget.video.analysisJson != null) {
      // Se c'è un'analisi, naviga alla chat specifica
      try {
        final stats = ScoutStatistics.fromJson(widget.video.analysisJson!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoAnalysisPage(
              initialResults: stats,
              initialAnalysisId: widget.video.id,
            ),
          ),
        );
      } catch (e) {
        // Se c'è un errore nel parsing, vai alla pagina video generica
        context.go('/video');
      }
    } else {
      // Se non c'è analisi, vai alla pagina video generica
      context.go('/video');
    }
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Elimina clip', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Eliminare "${widget.video.videoName}"?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Elimina', style: TextStyle(color: AppTheme.errorColor))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(matchesRepositoryProvider).deleteMatchVideo(widget.video.id);
      widget.onDeleted();
    }
  }

  static Color _statusColor(AnalysisStatus s) {
    switch (s) {
      case AnalysisStatus.done: return AppTheme.accentGreen;
      case AnalysisStatus.processing: return const Color(0xFF7C4DFF);
      case AnalysisStatus.error: return AppTheme.errorColor;
      case AnalysisStatus.cancelled: return Colors.orange;
      default: return AppTheme.textMuted;
    }
  }

  static String _statusLabel(AnalysisStatus s) {
    switch (s) {
      case AnalysisStatus.done: return 'Analizzata';
      case AnalysisStatus.processing: return 'In analisi...';
      case AnalysisStatus.cancelled: return 'Interrotta';
      case AnalysisStatus.error: return 'Errore';
      default: return 'In attesa';
    }
  }

  static String _fmtN(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  Future<void> _onStopAnalysis() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Ferma analisi', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Vuoi interrompere l\'analisi in corso? Lo stato verrà impostato su "Interrotta".', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ferma', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Set cancellation flag immediately
      setState(() => _isCancelled = true);
      
      // Update database status
      try {
        await ref.read(matchesRepositoryProvider).updateVideoStatus(widget.video.id, AnalysisStatus.cancelled);
        if (mounted) {
          widget.onAnalyzed();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Analisi interrotta'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('Errore stop analisi: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }
  }


  Future<void> _onForceReset() async {
    // Force reset for stuck processing state
    setState(() => _isCancelled = true);
    await ref.read(matchesRepositoryProvider).updateVideoStatus(widget.video.id, AnalysisStatus.pending);
    if (mounted) {
      widget.onAnalyzed();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stato resettato a "In attesa"'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// ── Empty clips ───────────────────────────────────────────────────
class _EmptyClips extends ConsumerWidget {
  final MatchModel match;
  final VoidCallback onUploaded;
  const _EmptyClips({required this.match, required this.onUploaded});

  void _pick(WidgetRef ref) {
    final input = html.FileUploadInputElement()..accept = 'video/*';
    input.click();
    input.onChange.listen((_) async {
      final file = input.files?.first;
      if (file == null) return;
      final userId = ref.read(userProvider).valueOrNull?.id ?? '';
      final newVideo = MatchVideoModel(
        id: '', matchId: match.id, userId: userId, sequenceOrder: 0,
        videoName: file.name, analysisStatus: AnalysisStatus.pending,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      await ref.read(matchesRepositoryProvider).createMatchVideo(newVideo);
      onUploaded();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_file_outlined, size: 52, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text('Nessuna clip ancora', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('Carica i video della partita per analizzarli', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _pick(ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Aggiungi clip'),
          ),
        ],
      ),
    );
  }
}

// ── Analysis Row ──────────────────────────────────────────────────
class _AnalysisRow extends ConsumerWidget {
  final Map<String, dynamic> analysis;
  final MatchModel match;
  final VoidCallback onDeleted;

  const _AnalysisRow({
    super.key,
    required this.analysis,
    required this.match,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoName = analysis['video_name'] as String? ?? 'Analisi Video';
    final createdAt = analysis['created_at'] as String?;
    
    DateTime? date;
    if (createdAt != null) {
      try {
        date = DateTime.parse(createdAt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3FB950).withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _navigateToAnalysis(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // AI Badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3FB950).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Color(0xFF3FB950),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.analytics_rounded,
                            size: 14,
                            color: Color(0xFF3FB950),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'ANALISI AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3FB950),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        videoName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Actions
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF3FB950)),
                  tooltip: 'Vai alla chat AI',
                  onPressed: () => _navigateToAnalysis(context),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted),
                  tooltip: 'Elimina analisi',
                  onPressed: () => _onDelete(context, ref),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToAnalysis(BuildContext context) {
    final analysisData = analysis['analysis_data'] as Map<String, dynamic>?;
    if (analysisData != null) {
      try {
        final stats = ScoutStatistics.fromJson(analysisData);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoAnalysisPage(
              initialResults: stats,
              initialAnalysisId: analysis['id'] as String,
            ),
          ),
        );
      } catch (e) {
        context.go('/video');
      }
    } else {
      context.go('/video');
    }
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final videoName = analysis['video_name'] as String? ?? 'questa analisi';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Elimina analisi', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Eliminare "$videoName"?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Elimina', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await ref.read(videoAnalysisRepositoryProvider).deleteAnalysis(analysis['id'] as String);
        onDeleted();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Analisi eliminata'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// ── Color Chip ────────────────────────────────────────────────────
class _ColorChip extends StatelessWidget {
  final String color;
  final String label;
  const _ColorChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    Color c = AppTheme.textMuted;
    try { c = Color(int.parse(color.replaceFirst('#', '0xFF'))); } catch (_) {}
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: AppTheme.sidebarBorderColor))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }
}
