import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';
import 'package:lavagna_tattica/features/matches/data/models/match_model.dart';
import 'package:lavagna_tattica/features/matches/data/models/match_video_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lavagna_tattica/features/matches/data/repositories/matches_repository.dart';
import 'package:lavagna_tattica/features/video_analysis/data/models/scout_statistics.dart';
import 'package:lavagna_tattica/features/video_analysis/data/repositories/ai_analysis_repository.dart';
import 'package:lavagna_tattica/features/video_analysis/presentation/widgets/tactical_chat_widget.dart';
import 'package:lavagna_tattica/features/matches/providers/matches_providers.dart';

class MatchDetailPage extends ConsumerWidget {
  final String matchId;
  const MatchDetailPage({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(matchVideosProvider(matchId));
    final matchAsync = ref.watch(_matchProvider(matchId));

    return matchAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))),
      error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
      data: (match) {
        if (match == null) return const Scaffold(body: Center(child: Text('Partita non trovata')));
        return videosAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))),
          error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
          data: (videos) {
            final analyzedVideos = videos.where((v) => v.isAnalyzed && v.analysisJson != null).toList();
            final aggregated = _buildAggregatedStats(analyzedVideos, match);

            return DefaultTabController(
              length: 2,
              child: Scaffold(
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
                  bottom: const TabBar(
                    indicatorColor: Color(0xFFF59E0B),
                    labelColor: Color(0xFFF59E0B),
                    unselectedLabelColor: AppTheme.textSecondary,
                    tabs: [
                      Tab(icon: Icon(Icons.video_library_rounded, size: 16), text: 'Clip'),
                      Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 16), text: 'Chat'),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    // ── Tab 1: Clips ─────────────────────────
                    Column(
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
                          child: videos.isEmpty
                              ? _EmptyClips(match: match, onUploaded: () => ref.invalidate(matchVideosProvider(matchId)))
                              : ReorderableListView.builder(
                                  buildDefaultDragHandles: false,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: videos.length,
                                  onReorder: (oldIdx, newIdx) async {
                                    if (newIdx > oldIdx) newIdx--;
                                    final repo = ref.read(matchesRepositoryProvider);
                                    await repo.updateVideoOrder(videos[oldIdx].id, newIdx);
                                    ref.invalidate(matchVideosProvider(matchId));
                                  },
                                  itemBuilder: (ctx, i) => _ClipRow(
                                    key: ValueKey(videos[i].id),
                                    video: videos[i],
                                    index: i,
                                    match: match,
                                    onDeleted: () => ref.invalidate(matchVideosProvider(matchId)),
                                    onAnalyzed: () => ref.invalidate(matchVideosProvider(matchId)),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    // ── Tab 2: Chat aggregata ────────────────
                    aggregated == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.textMuted),
                                SizedBox(height: 16),
                                Text('Analizza almeno una clip\nper abilitare la chat', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                              ],
                            ),
                          )
                        : TacticalChatWidget(
                            analysis: aggregated,
                            analysisId: 'match_$matchId',
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Aggrega tutte le analisi delle clip in un unico ScoutStatistics per la chat
  static ScoutStatistics? _buildAggregatedStats(List<MatchVideoModel> analyzed, MatchModel match) {
    if (analyzed.isEmpty) return null;
    try {
      final all = analyzed.map((v) => ScoutStatistics.fromJson(v.analysisJson!)).toList();
      if (all.length == 1) return all.first;

      int hShots = 0, aShots = 0, hRec = 0, aRec = 0;
      double hXg = 0, aXg = 0, hPoss = 0, aPoss = 0;
      for (final s in all) {
        hShots += s.homeTeam.offensivePhase.shots.total;
        aShots += s.awayTeam.offensivePhase.shots.total;
        hRec   += s.homeTeam.defensivePhase.pressureAndRecovery.ballRecoveries;
        aRec   += s.awayTeam.defensivePhase.pressureAndRecovery.ballRecoveries;
        hXg    += s.homeTeam.advancedIndicators.teamXG;
        aXg    += s.awayTeam.advancedIndicators.teamXG;
        hPoss  += s.homeTeam.possessionAndBuildUp.totalPossessionPercent;
        aPoss  += s.awayTeam.possessionAndBuildUp.totalPossessionPercent;
      }
      final n = all.length;
      final base = all.first;
      return base.copyWith(
        homeTeam: base.homeTeam.copyWith(
          teamName: match.homeTeam,
          possessionAndBuildUp: base.homeTeam.possessionAndBuildUp.copyWith(totalPossessionPercent: (hPoss / n).round()),
          offensivePhase: base.homeTeam.offensivePhase.copyWith(shots: base.homeTeam.offensivePhase.shots.copyWith(total: hShots)),
          defensivePhase: base.homeTeam.defensivePhase.copyWith(pressureAndRecovery: base.homeTeam.defensivePhase.pressureAndRecovery.copyWith(ballRecoveries: hRec)),
          advancedIndicators: base.homeTeam.advancedIndicators.copyWith(teamXG: hXg),
        ),
        awayTeam: base.awayTeam.copyWith(
          teamName: match.awayTeam,
          possessionAndBuildUp: base.awayTeam.possessionAndBuildUp.copyWith(totalPossessionPercent: (aPoss / n).round()),
          offensivePhase: base.awayTeam.offensivePhase.copyWith(shots: base.awayTeam.offensivePhase.shots.copyWith(total: aShots)),
          defensivePhase: base.awayTeam.defensivePhase.copyWith(pressureAndRecovery: base.awayTeam.defensivePhase.pressureAndRecovery.copyWith(ballRecoveries: aRec)),
          advancedIndicators: base.awayTeam.advancedIndicators.copyWith(teamXG: aXg),
        ),
        reportSummary: base.reportSummary.copyWith(
          overview: 'Analisi aggregata di $n clip — ${match.displayTitle}',
          analysis: analyzed.map((v) {
            final s = ScoutStatistics.fromJson(v.analysisJson!);
            return 'Clip ${v.sequenceOrder + 1}: ${s.reportSummary.overview}';
          }).join('\n\n'),
        ),
      );
    } catch (_) {
      return null;
    }
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
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
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
            ? AppTheme.accentGreen.withOpacity(0.3) 
            : AppTheme.sidebarBorderColor,
          width: widget.video.isAnalyzed ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  colors: [AppTheme.accentGreen.withOpacity(0.2), AppTheme.accentGreen.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
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
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.3), width: 0.5),
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
                        Icon(Icons.token_outlined, size: 12, color: AppTheme.textMuted.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          '${_fmtN(widget.video.totalTokens)} tok',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted.withOpacity(0.9),
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
                  // Restart button for error or cancelled
                  IconButton(
                    icon: const Icon(Icons.replay_rounded, color: AppTheme.accentGreen),
                    tooltip: 'Riavvia analisi',
                    onPressed: _onRestartTap,
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
                  if (!widget.video.isAnalyzed)
                    IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, color: AppTheme.accentGreen),
                      tooltip: 'Analizza',
                      onPressed: _onAnalyzeTap,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  if (widget.video.isAnalyzed)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFFF59E0B)),
                      tooltip: 'Ri-analizza',
                      onPressed: _onReanalyzeTap,
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

  void _onAnalyzeTap() {
    setState(() => _isCancelled = false);
    if (widget.match.team1Color == null) {
      showDialog(
        context: context,
        builder: (_) => _TeamColorsDialog(
          match: widget.match,
          onConfirmed: (t1color, t2color) async {
            await ref.read(matchesRepositoryProvider).updateMatchColors(widget.match.id, t1color, t2color);
            ref.invalidate(_matchProvider(widget.match.id));
            if (context.mounted) _startAnalysis(t1color, t2color);
          },
        ),
      );
    } else {
      _startAnalysis(widget.match.team1Color!, widget.match.team2Color!);
    }
  }

  void _onReanalyzeTap() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Ri-analizza clip', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Questa operazione:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            _warningItem(Icons.token_outlined, 'Consumerà nuovi token AI', const Color(0xFFF59E0B)),
            _warningItem(Icons.delete_sweep_outlined, 'Sovrascriverà l\'analisi precedente', AppTheme.errorColor),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _isCancelled = false);
              _startAnalysis(widget.match.team1Color ?? '', widget.match.team2Color ?? '');
            },
            child: const Text('Procedi', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _warningItem(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Future<void> _startAnalysis(String t1color, String t2color) async {
    // Use HTML file picker for web (more reliable than ImagePicker)
    final input = html.FileUploadInputElement()..accept = 'video/*';
    input.click();

    final completer = Completer<html.File?>();
    input.onChange.listen((_) {
      completer.complete(input.files?.first);
    });
    // Handle cancel
    html.window.onBlur.listen((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!completer.isCompleted) completer.complete(null);
    });

    final file = await completer.future;
    if (file == null) return;

    // Create XFile from html.File for the AI repository
    final reader = html.FileReader();
    final readCompleter = Completer<Uint8List>();
    reader.onLoad.listen((_) {
      readCompleter.complete(reader.result as Uint8List);
    });
    reader.readAsArrayBuffer(file);
    final bytes = await readCompleter.future;

    // Save bytes to a temporary blob and create XFile
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrl(blob);

    final repo = ref.read(matchesRepositoryProvider);
    final aiRepo = ref.read(aiAnalysisRepositoryProvider);

    // Set processing state
    await repo.updateVideoStatus(widget.video.id, AnalysisStatus.processing);
    widget.onAnalyzed();

    try {
      final teamCtx = TeamContext(
        homeName: widget.match.homeTeam,
        homeColor: t1color,
        awayName: widget.match.awayTeam,
        awayColor: t2color,
      );

      // Use internal method to upload bytes directly
      final result = await aiRepo.analyzeMatchVideoFromBytes(bytes, file.name, teamContext: teamCtx);

      // Check if analysis was cancelled during processing
      if (_isCancelled || !mounted) {
        debugPrint('Analisi completata ma era stata cancellata, risultato scartato');
        return;
      }

      await repo.updateVideoAnalysis(
        videoId: widget.video.id,
        analysisJson: result.statistics.toJson(),
        status: AnalysisStatus.done,
        promptTokens: result.promptTokens,
        completionTokens: result.completionTokens,
        totalTokens: result.totalTokens,
        modelName: 'gemini-flash-lite',
      );
    } catch (e) {
      debugPrint('Errore analisi: $e');
      if (!_isCancelled && mounted) {
        await repo.updateVideoStatus(widget.video.id, AnalysisStatus.error);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore analisi: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
    if (mounted) widget.onAnalyzed();
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

  Future<void> _onRestartTap() async {
    // Reset to pending before restarting
    await ref.read(matchesRepositoryProvider).updateVideoStatus(widget.video.id, AnalysisStatus.pending);
    widget.onAnalyzed();
    // Wait a bit for UI to update
    await Future.delayed(const Duration(milliseconds: 200));
    _onAnalyzeTap();
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

// ── Team Colors Dialog ────────────────────────────────────────────
class _TeamColorsDialog extends StatefulWidget {
  final MatchModel match;
  final void Function(String t1color, String t2color) onConfirmed;
  const _TeamColorsDialog({required this.match, required this.onConfirmed});

  @override
  State<_TeamColorsDialog> createState() => _TeamColorsDialogState();
}

class _TeamColorsDialogState extends State<_TeamColorsDialog> {
  Color _color1 = const Color(0xFF1565C0);
  Color _color2 = const Color(0xFFB71C1C);

  static const _presets = [
    Color(0xFF1565C0), Color(0xFFB71C1C), Color(0xFF2E7D32), Color(0xFFF57F17),
    Color(0xFF6A1B9A), Color(0xFF00838F), Color(0xFF37474F), Color(0xFFFFFFFF),
    Color(0xFF000000), Color(0xFFFDD835), Color(0xFFFF6F00), Color(0xFFAD1457),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('Colori squadre', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleziona il colore principale della maglia per ciascuna squadra. Verranno usati per l\'analisi AI.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            _TeamColorRow(
              teamName: widget.match.homeTeam,
              selected: _color1,
              presets: _presets,
              onChanged: (c) => setState(() => _color1 = c),
            ),
            const SizedBox(height: 12),
            _TeamColorRow(
              teamName: widget.match.awayTeam,
              selected: _color2,
              presets: _presets,
              onChanged: (c) => setState(() => _color2 = c),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onConfirmed(
              '#${_color1.value.toRadixString(16).substring(2).toUpperCase()}',
              '#${_color2.value.toRadixString(16).substring(2).toUpperCase()}',
            );
          },
          child: const Text('Conferma e analizza'),
        ),
      ],
    );
  }
}

class _TeamColorRow extends StatelessWidget {
  final String teamName;
  final Color selected;
  final List<Color> presets;
  final ValueChanged<Color> onChanged;
  const _TeamColorRow({required this.teamName, required this.selected, required this.presets, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 20, height: 20, decoration: BoxDecoration(color: selected, shape: BoxShape.circle, border: Border.all(color: AppTheme.sidebarBorderColor))),
            const SizedBox(width: 8),
            Text(teamName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: presets.map((c) {
            final isSelected = c.value == selected.value;
            return GestureDetector(
              onTap: () => onChanged(c),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.accentGreen : AppTheme.sidebarBorderColor,
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected ? [BoxShadow(color: AppTheme.accentGreen.withOpacity(0.4), blurRadius: 6)] : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
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
