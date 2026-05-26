import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';
import 'package:lavagna_tattica/features/video_analysis/data/repositories/ai_analysis_repository.dart';
import 'package:lavagna_tattica/features/video_analysis/data/repositories/video_analysis_repository.dart';
import 'package:lavagna_tattica/features/video_analysis/data/models/scout_statistics.dart';
import 'package:lavagna_tattica/features/video_analysis/data/providers/video_service_provider.dart';
import 'package:lavagna_tattica/features/video_analysis/presentation/widgets/tactical_chat_widget.dart';
import 'package:lavagna_tattica/features/video_analysis/presentation/analyses_archive_page.dart';
import 'package:lavagna_tattica/features/matches/presentation/calendar_page.dart';
import 'package:lavagna_tattica/features/matches/presentation/matches_list_page.dart';
import 'package:lavagna_tattica/features/matches/presentation/match_dashboard_page.dart';
import 'package:lavagna_tattica/features/matches/providers/matches_providers.dart';
import 'package:lavagna_tattica/features/matches/data/models/match_model.dart';
import 'package:lavagna_tattica/features/matches/data/repositories/matches_repository.dart';

class VideoAnalysisPage extends ConsumerStatefulWidget {
  final ScoutStatistics? initialResults;
  final String? initialAnalysisId;

  const VideoAnalysisPage({
    super.key,
    this.initialResults,
    this.initialAnalysisId,
  });

  @override
  ConsumerState<VideoAnalysisPage> createState() => _VideoAnalysisPageState();
}

class _TipBullet extends StatelessWidget {
  final String text;

  const _TipBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoAnalysisPageState extends ConsumerState<VideoAnalysisPage> {
  XFile? _selectedVideo;
  VideoPlayerController? _videoController;
  bool _isProcessing = false;
  String _processingStatus = '';
  ScoutStatistics? _analysisResults;
  String? _savedAnalysisId;
  int _totalTokens = 0;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialResults != null) {
      _analysisResults = widget.initialResults;
      _savedAnalysisId = widget.initialAnalysisId;
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedVideo = video;
        _analysisResults = null;
        _savedAnalysisId = null;
        _totalTokens = 0;
      });
      _initializePreview();
    }
  }

  Future<void> _initializePreview() async {
    if (_selectedVideo == null) return;

    await _videoController?.dispose();
    
    if (kIsWeb) {
      _videoController = VideoPlayerController.network(_selectedVideo!.path)
        ..initialize().then((_) {
          setState(() {});
        });
    } else {
      _videoController = VideoPlayerController.file(File(_selectedVideo!.path))
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  Future<void> _analyzeAndSave() async {
    final user = ref.read(userProvider).valueOrNull;
    if (user == null || _selectedVideo == null) return;

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Preparazione video...';
    });

    try {
      final videoService = ref.read(videoServiceProvider);
      final aiRepo = ref.read(aiAnalysisRepositoryProvider);
      
      setState(() => _processingStatus = kIsWeb ? 'Caricamento video...' : 'Compressione video (max 30s)...');
      final processedVideo = await videoService.processVideo(_selectedVideo!);
      
      XFile videoToAnalyze;
      if (processedVideo == null) {
        videoToAnalyze = _selectedVideo!;
      } else if (processedVideo is File) {
        videoToAnalyze = XFile(processedVideo.path);
      } else {
        videoToAnalyze = processedVideo as XFile;
      }

      setState(() => _processingStatus = 'Analisi tattica in corso (Gemini Pro)...');
      final result = await aiRepo.analyzeMatchVideo(videoToAnalyze);
      
      setState(() {
        _analysisResults = result.statistics;
        _totalTokens = result.totalTokens;
        _processingStatus = 'Salvataggio risultati...';
      });

      final analysisRepo = ref.read(videoAnalysisRepositoryProvider);
      final videoName = _selectedVideo!.name;
      final analysisId = await analysisRepo.saveAnalysis(
        userId: user.id,
        videoName: videoName,
        analysis: result.statistics,
        promptTokens: result.promptTokens,
        completionTokens: result.completionTokens,
        totalTokens: result.totalTokens,
      );

      setState(() {
        _savedAnalysisId = analysisId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Analisi completata e salvata con successo!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Mostra modale per associare l'analisi a una partita
        _showMatchAssociationDialog(analysisId);
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Errore Analisi: $e');
        String errorMessage = e.toString().contains('Exception:') 
            ? e.toString().split('Exception:').last 
            : e.toString();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            duration: const Duration(seconds: 7),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Dettagli',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Dettaglio Errore'),
                    content: SingleChildScrollView(child: Text(e.toString())),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = '';
        });
      }
    }
  }

  Future<void> _showMatchAssociationDialog(String analysisId) async {
    try {
      // Carica le partite dal repository
      final matchesRepo = ref.read(matchesRepositoryProvider);
      final matches = await matchesRepo.getMatches();
      
      if (!mounted) return;
      
      if (matches.isEmpty) {
        // Nessuna partita disponibile
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: const Text('Nessuna partita disponibile', style: TextStyle(color: AppTheme.textPrimary)),
            content: const Text(
              'Non ci sono partite a cui associare questa analisi. Crea prima una partita dalla sezione Partite o Calendario.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      
      // Mostra dialog con lista partite
      final selectedMatch = await showDialog<MatchModel?>(
        context: context,
        builder: (context) => _MatchSelectionDialog(matches: matches),
      );
      
      if (selectedMatch != null && mounted) {
        try {
          await ref.read(videoAnalysisRepositoryProvider).associateAnalysisToMatch(analysisId, selectedMatch.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Analisi associata a "${selectedMatch.displayTitle}"'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Errore: $e'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento delle partite: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isHistoricalView = _savedAnalysisId != null && _analysisResults != null;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Video AI'),
          actions: [
            if (!isHistoricalView)
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AnalysesArchivePage())),
                tooltip: 'Archivio Analisi',
              ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFFF59E0B),
            labelColor: Color(0xFFF59E0B),
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.videocam_rounded, size: 16), text: 'Analisi'),
              Tab(icon: Icon(Icons.sports_soccer_rounded, size: 16), text: 'Partite'),
              Tab(icon: Icon(Icons.calendar_month_rounded, size: 16), text: 'Calendario'),
              Tab(icon: Icon(Icons.bar_chart_rounded, size: 16), text: 'Dashboard'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── Tab 1: Analisi singola ────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Se siamo in vista storica, mostriamo un header diverso invece del box info caricamento
            if (isHistoricalView)
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.green, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.greenAccent),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Analisi Salvata',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              'Questa analisi è archiviata nel tuo profilo ed è consultabile in ogni momento.',
                              style: TextStyle(color: Colors.grey[400], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Carica un video della partita. L\'AI analizzerà tattiche, statistiche e movimenti dei giocatori.',
                          style: TextStyle(color: Colors.grey[300]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
            const SizedBox(height: 32),

            // Area Video / Upload: La nascondiamo del tutto se siamo in vista storica per pulire l'interfaccia
            if (!isHistoricalView) ...[
              Container(
                height: _selectedVideo == null ? 280 : 360,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: _selectedVideo == null
                    ? InkWell(
                        onTap: _pickVideo,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_upload_rounded,
                                  size: 56, color: Colors.white70),
                              const SizedBox(height: 16),
                              const Text(
                                'Carica il video della partita',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Supportati MP4 e MOV • Qualsiasi dimensione',
                                style: TextStyle(color: Colors.grey[400]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                child: const Text(
                                  'Tocca per selezionare un file',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_videoController != null &&
                                _videoController!.value.isInitialized)
                              VideoPlayer(_videoController!)
                            else
                              const CircularProgressIndicator(),
                            IconButton(
                              icon: Icon(
                                _videoController?.value.isPlaying ?? false
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                size: 64,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              onPressed: () {
                                setState(() {
                                  _videoController!.value.isPlaying
                                      ? _videoController!.pause()
                                      : _videoController!.play();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              if (_selectedVideo == null)
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AnalysesArchivePage()),
                      );
                    },
                    icon: const Icon(Icons.history, color: Colors.cyanAccent),
                    label: const Text(
                      'Sfoglia Storico Analisi e Chat',
                      style: TextStyle(
                          color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cosa puoi fare qui',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isHistoricalView) ...[
                    const _TipBullet(text: 'Esplora i dati statistici raccolti durante il match'),
                    const _TipBullet(text: 'Rivedi l\'analisi tattica prodotta dall\'AI'),
                    const _TipBullet(text: 'Continua la conversazione con il Coach Assistant'),
                    const _TipBullet(text: 'Esporta o condividi i punti chiave della partita'),
                  ] else ...[
                    const _TipBullet(text: 'Carica il video del match per iniziare l\'analisi'),
                    const _TipBullet(text: 'Ricevi un report tattico completo e automatizzato'),
                    const _TipBullet(text: 'Chatta con l\'IA per approfondire aspetti specifici'),
                    const _TipBullet(text: 'Salva l\'analisi per consultarla in futuro'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_selectedVideo != null && !isHistoricalView) ...[
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _analyzeAndSave,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.analytics_rounded),
                label: Text(_isProcessing ? _processingStatus : 'Analizza e Salva'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isProcessing ? null : _pickVideo,
                child: const Text('Cambia Video'),
              ),
            ],

            if (_analysisResults != null) ...[
              const Divider(height: 48),
              const Text(
                'Risultati Analisi Tattica',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _analysisResults!.reportSummary.overview,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(_analysisResults!.reportSummary.analysis),
                      const Divider(height: 32),
                      
                      Row(
                        children: [
                          Expanded(child: Text(_analysisResults!.homeTeam.teamName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                          const SizedBox(width: 16, child: Text('VS', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey))),
                          Expanded(child: Text(_analysisResults!.awayTeam.teamName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _ComparisonRow(
                        label: 'Possesso',
                        homeValue: '${_analysisResults!.homeTeam.possessionAndBuildUp.totalPossessionPercent}%',
                        awayValue: '${_analysisResults!.awayTeam.possessionAndBuildUp.totalPossessionPercent}%',
                      ),
                      _ComparisonRow(
                        label: 'Tiri Totali',
                        homeValue: '${_analysisResults!.homeTeam.offensivePhase.shots.total}',
                        awayValue: '${_analysisResults!.awayTeam.offensivePhase.shots.total}',
                      ),
                      _ComparisonRow(
                        label: 'Expected Goals (xG)',
                        homeValue: _analysisResults!.homeTeam.advancedIndicators.teamXG.toStringAsFixed(1),
                        awayValue: _analysisResults!.awayTeam.advancedIndicators.teamXG.toStringAsFixed(1),
                      ),
                      _ComparisonRow(
                        label: 'Recuperi Palla',
                        homeValue: '${_analysisResults!.homeTeam.defensivePhase.pressureAndRecovery.ballRecoveries}',
                        awayValue: '${_analysisResults!.awayTeam.defensivePhase.pressureAndRecovery.ballRecoveries}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TacticalChatWidget(
                analysisId: _savedAnalysisId,
                analysis: _analysisResults!,
              ),
            ],
          ],
        ),
            ),
            // ── Tab 2: Partite ────────────────────────────────
            const MatchesListPage(),
            // ── Tab 3: Calendario ─────────────────────────────
            const CalendarPage(),
            // ── Tab 4: Dashboard multi-partita ────────────────
            const MatchDashboardPage(),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String homeValue;
  final String awayValue;

  const _ComparisonRow({
    required this.label,
    required this.homeValue,
    required this.awayValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(homeValue, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              const Expanded(child: SizedBox()),
              Expanded(child: Text(awayValue, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Match Selection Dialog ────────────────────────────────────────
class _MatchSelectionDialog extends StatelessWidget {
  final List<MatchModel> matches;
  
  const _MatchSelectionDialog({required this.matches});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('Associa a una partita', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Seleziona la partita a cui associare questa analisi:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final match = matches[index];
                  return Card(
                    color: AppTheme.surfaceColor,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.sports_soccer, color: AppTheme.accentGreen),
                      title: Text(
                        match.displayTitle,
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      subtitle: match.matchDate != null
                          ? Text(
                              '${match.matchDate!.day}/${match.matchDate!.month}/${match.matchDate!.year}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            )
                          : null,
                      onTap: () => Navigator.pop(context, match),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Salta'),
        ),
      ],
    );
  }
}
