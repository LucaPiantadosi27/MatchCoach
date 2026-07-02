import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/matches/data/models/match_model.dart';
import 'package:lavagna_tattica/features/matches/data/repositories/matches_repository.dart';
import 'package:lavagna_tattica/features/matches/providers/matches_providers.dart';
import 'package:lavagna_tattica/features/video_analysis/data/models/scout_statistics.dart';

class MatchDashboardPage extends ConsumerWidget {
  const MatchDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);

    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen)),
      error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: AppTheme.errorColor))),
      data: (matches) {
        if (matches.isEmpty) {
          return _EmptyDashboard();
        }
        return _DashboardContent(matches: matches);
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────
class _EmptyDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart_rounded, size: 56, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text('Nessuna partita ancora', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('Crea partite e analizza le clip per vedere le statistiche', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/video'),
            icon: const Icon(Icons.sports_soccer_rounded),
            label: const Text('Vai alle Partite'),
          ),
        ],
      ),
    );
  }
}

// ── Main dashboard content ────────────────────────────────────────
class _DashboardContent extends ConsumerWidget {
  final List<MatchModel> matches;
  const _DashboardContent({required this.matches});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<_MatchStats>>(
      future: _loadAllStats(ref, matches),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Summary cards row ───────────────────────────
              _SummaryRow(matches: matches, stats: stats),
              const SizedBox(height: 20),

              // ── Per-team trend ──────────────────────────────
              if (isLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppTheme.accentGreen),
                ))
              else if (stats.isNotEmpty) ...[
                _SectionHeader(icon: Icons.trending_up_rounded, title: 'POSSESSO MEDIO PER PARTITA'),
                const SizedBox(height: 10),
                _PossessionChart(stats: stats),
                const SizedBox(height: 20),

                _SectionHeader(icon: Icons.sports_soccer_rounded, title: 'TIRI PER PARTITA'),
                const SizedBox(height: 10),
                _ShotsChart(stats: stats),
                const SizedBox(height: 20),

                _SectionHeader(icon: Icons.bolt_rounded, title: 'xG CUMULATIVO PER PARTITA'),
                const SizedBox(height: 10),
                _XgChart(stats: stats),
                const SizedBox(height: 20),
              ],

              // ── Matches list with status ────────────────────
              _SectionHeader(icon: Icons.list_alt_rounded, title: 'TUTTE LE PARTITE'),
              const SizedBox(height: 10),
              ...matches.map((m) => _MatchStatusRow(
                match: m,
                stat: stats.where((s) => s.matchId == m.id).firstOrNull,
                onTap: () => context.push('/matches/${m.id}'),
              )),
            ],
          ),
        );
      },
    );
  }

  Future<List<_MatchStats>> _loadAllStats(WidgetRef ref, List<MatchModel> matches) async {
    final repo = ref.read(matchesRepositoryProvider);
    final result = <_MatchStats>[];
    for (final m in matches) {
      try {
        final videos = await repo.getMatchVideos(m.id);
        final analyzed = videos.where((v) => v.isAnalyzed && v.analysisJson != null).toList();
        if (analyzed.isEmpty) {
          result.add(_MatchStats(matchId: m.id, match: m, clipCount: videos.length, analyzedCount: 0));
          continue;
        }
        final allStats = analyzed.map((v) => ScoutStatistics.fromJson(v.analysisJson!)).toList();
        int hShots = 0, aShots = 0;
        double hXg = 0, aXg = 0, hPoss = 0, aPoss = 0;
        for (final s in allStats) {
          hShots += s.homeTeam.offensivePhase.shots.total;
          aShots += s.awayTeam.offensivePhase.shots.total;
          hXg    += s.homeTeam.advancedIndicators.teamXG;
          aXg    += s.awayTeam.advancedIndicators.teamXG;
          hPoss  += s.homeTeam.possessionAndBuildUp.totalPossessionPercent;
          aPoss  += s.awayTeam.possessionAndBuildUp.totalPossessionPercent;
        }
        final n = allStats.length;
        result.add(_MatchStats(
          matchId: m.id,
          match: m,
          clipCount: videos.length,
          analyzedCount: analyzed.length,
          homePossession: hPoss / n,
          awayPossession: aPoss / n,
          homeShots: hShots,
          awayShots: aShots,
          homeXg: hXg,
          awayXg: aXg,
        ));
      } catch (_) {
        result.add(_MatchStats(matchId: m.id, match: m, clipCount: 0, analyzedCount: 0));
      }
    }
    return result;
  }
}

// ── Data model ────────────────────────────────────────────────────
class _MatchStats {
  final String matchId;
  final MatchModel match;
  final int clipCount;
  final int analyzedCount;
  final double homePossession;
  final double awayPossession;
  final int homeShots;
  final int awayShots;
  final double homeXg;
  final double awayXg;

  bool get hasData => analyzedCount > 0;

  const _MatchStats({
    required this.matchId,
    required this.match,
    required this.clipCount,
    required this.analyzedCount,
    this.homePossession = 0,
    this.awayPossession = 0,
    this.homeShots = 0,
    this.awayShots = 0,
    this.homeXg = 0,
    this.awayXg = 0,
  });
}

// ── Summary row ───────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final List<MatchModel> matches;
  final List<_MatchStats> stats;
  const _SummaryRow({required this.matches, required this.stats});

  @override
  Widget build(BuildContext context) {
    final analyzed = stats.where((s) => s.hasData).length;
    final totalClips = stats.fold(0, (a, s) => a + s.clipCount);
    final totalXg = stats.fold(0.0, (a, s) => a + s.homeXg + s.awayXg);

    return Row(
      children: [
        Expanded(child: _StatCard(value: '${matches.length}', label: 'Partite', icon: Icons.sports_soccer_rounded, color: AppTheme.accentGreen)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: '$analyzed', label: 'Analizzate', icon: Icons.check_circle_outline_rounded, color: const Color(0xFF7C4DFF))),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: '$totalClips', label: 'Clip totali', icon: Icons.video_file_outlined, color: Colors.orange)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: totalXg.toStringAsFixed(1), label: 'xG totali', icon: Icons.bolt_rounded, color: const Color(0xFFF59E0B))),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.sidebarBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 7),
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.3)),
      ],
    );
  }
}

// ── Possession chart ──────────────────────────────────────────────
class _PossessionChart extends StatelessWidget {
  final List<_MatchStats> stats;
  const _PossessionChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final withData = stats.where((s) => s.hasData).toList();
    if (withData.isEmpty) return const _NoDataPlaceholder();
    return Column(
      children: withData.map((s) {
        final home = s.homePossession.clamp(0, 100).toDouble();
        final label = '${s.match.homeTeam} vs ${s.match.awayTeam}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              _SplitBar(
                leftValue: home / 100,
                rightValue: (100 - home) / 100,
                leftColor: _teamColor(s.match.team1Color),
                rightColor: _teamColor(s.match.team2Color),
                leftLabel: '${home.round()}%',
                rightLabel: '${(100 - home).round()}%',
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Shots chart ───────────────────────────────────────────────────
class _ShotsChart extends StatelessWidget {
  final List<_MatchStats> stats;
  const _ShotsChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final withData = stats.where((s) => s.hasData).toList();
    if (withData.isEmpty) return const _NoDataPlaceholder();
    final maxShots = withData.fold(1, (m, s) => s.homeShots + s.awayShots > m ? s.homeShots + s.awayShots : m);
    return Column(
      children: withData.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${s.match.homeTeam} vs ${s.match.awayTeam}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              _SplitBar(
                leftValue: s.homeShots / maxShots,
                rightValue: s.awayShots / maxShots,
                leftColor: _teamColor(s.match.team1Color),
                rightColor: _teamColor(s.match.team2Color),
                leftLabel: '${s.homeShots}',
                rightLabel: '${s.awayShots}',
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── xG chart ─────────────────────────────────────────────────────
class _XgChart extends StatelessWidget {
  final List<_MatchStats> stats;
  const _XgChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final withData = stats.where((s) => s.hasData).toList();
    if (withData.isEmpty) return const _NoDataPlaceholder();
    final maxXg = withData.fold(0.01, (m, s) => (s.homeXg + s.awayXg) > m ? (s.homeXg + s.awayXg) : m);
    return Column(
      children: withData.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${s.match.homeTeam} vs ${s.match.awayTeam}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              _SplitBar(
                leftValue: s.homeXg / maxXg,
                rightValue: s.awayXg / maxXg,
                leftColor: _teamColor(s.match.team1Color),
                rightColor: _teamColor(s.match.team2Color),
                leftLabel: s.homeXg.toStringAsFixed(2),
                rightLabel: s.awayXg.toStringAsFixed(2),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Split bar widget ──────────────────────────────────────────────
class _SplitBar extends StatelessWidget {
  final double leftValue;
  final double rightValue;
  final Color leftColor;
  final Color rightColor;
  final String leftLabel;
  final String rightLabel;
  const _SplitBar({required this.leftValue, required this.rightValue, required this.leftColor, required this.rightColor, required this.leftLabel, required this.rightLabel});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = (leftValue + rightValue).clamp(0.01, double.infinity);
        final leftW = (leftValue / total) * constraints.maxWidth;
        final rightW = (rightValue / total) * constraints.maxWidth;
        return Row(
          children: [
            // Left bar
            Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  width: leftW.clamp(0, constraints.maxWidth),
                  height: 24,
                  decoration: BoxDecoration(
                    color: leftColor.withValues(alpha: 0.8),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(leftLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
            // Right bar
            Stack(
              alignment: Alignment.centerRight,
              children: [
                Container(
                  width: rightW.clamp(0, constraints.maxWidth),
                  height: 24,
                  decoration: BoxDecoration(
                    color: rightColor.withValues(alpha: 0.8),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(rightLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Match status row ──────────────────────────────────────────────
class _MatchStatusRow extends StatelessWidget {
  final MatchModel match;
  final _MatchStats? stat;
  final VoidCallback onTap;
  const _MatchStatusRow({required this.match, required this.stat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final analyzed = stat?.analyzedCount ?? 0;
    final total = stat?.clipCount ?? 0;
    final hasData = stat?.hasData ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasData ? AppTheme.accentGreenDim.withValues(alpha: 0.4) : AppTheme.sidebarBorderColor,
          ),
        ),
        child: Row(
          children: [
            // Color dots
            if (match.team1Color != null && match.team2Color != null) ...[
              _dot(match.team1Color!),
              const SizedBox(width: 4),
              _dot(match.team2Color!),
              const SizedBox(width: 10),
            ] else
              const Icon(Icons.sports_soccer_outlined, size: 18, color: AppTheme.textMuted),
            const SizedBox(width: 6),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.displayTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  if (match.matchDate != null)
                    Text(DateFormat('dd/MM/yyyy').format(match.matchDate!), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            // Clip badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: hasData ? AppTheme.accentGreenDim.withValues(alpha: 0.15) : AppTheme.sidebarSectionColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                total == 0 ? 'Nessuna clip' : '$analyzed/$total clip',
                style: TextStyle(fontSize: 11, color: hasData ? AppTheme.accentGreen : AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _dot(String hex) {
    Color c = AppTheme.textMuted;
    try { c = Color(int.parse(hex.replaceFirst('#', '0xFF'))); } catch (_) {}
    return Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: AppTheme.sidebarBorderColor)));
  }
}

// ── Helpers ───────────────────────────────────────────────────────
Color _teamColor(String? hex) {
  if (hex == null) return AppTheme.accentGreen;
  try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); } catch (_) { return AppTheme.accentGreen; }
}

class _NoDataPlaceholder extends StatelessWidget {
  const _NoDataPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.sidebarBorderColor)),
      child: const Text('Nessuna clip analizzata ancora.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
    );
  }
}
