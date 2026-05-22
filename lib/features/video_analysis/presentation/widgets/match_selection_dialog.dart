import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/matches/data/models/match_model.dart';
import 'package:lavagna_tattica/features/matches/providers/matches_providers.dart';
import 'package:intl/intl.dart';

class MatchSelectionDialog extends ConsumerWidget {
  final String analysisId;
  final VoidCallback onAssociated;

  const MatchSelectionDialog({
    super.key,
    required this.analysisId,
    required this.onAssociated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sports_soccer,
                  color: AppTheme.accentGreen,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Associa a una partita',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Seleziona la partita a cui associare questa analisi video',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: matchesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.accentGreen,
                  ),
                ),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Errore nel caricamento delle partite',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                data: (matches) {
                  if (matches.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            color: AppTheme.textMuted,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nessuna partita disponibile',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Crea prima una partita dalla sezione Partite',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      return _MatchListItem(
                        match: match,
                        onTap: () async {
                          Navigator.of(context).pop(match.id);
                          onAssociated();
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.sidebarBorderColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Annulla'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchListItem extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;

  const _MatchListItem({
    required this.match,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.sidebarBorderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.sports_soccer,
                color: AppTheme.accentGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.displayTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(match.date),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeFormat.format(match.date),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  if (match.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          match.location,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
