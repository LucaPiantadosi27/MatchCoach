import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/core/supabase_client.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';

// ── Pricing per modello (USD per 1M token) ─────────────────────────
const _modelPricing = {
  'gemini-flash-lite-latest': 0.075,
  'gemini-2.0-flash-lite': 0.075,
  'gemini-flash-latest': 0.10,
  'gemini-2.0-flash': 0.10,
};

double _costForItem(Map<String, dynamic> item) {
  final tok = (item['total_tokens'] as int? ?? 0);
  final model = item['model_name'] as String? ?? '';
  double rate = 0.075;
  for (final entry in _modelPricing.entries) {
    if (model.contains(entry.key)) { rate = entry.value; break; }
  }
  return (tok / 1_000_000) * rate;
}

// ── Provider ──────────────────────────────────────────────────────
final _usageProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(userProvider).valueOrNull;
  if (user == null) return [];

  if (!user.isAdmin) {
    return await supabase
        .from('video_analyses')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
  }
  return await supabase
      .from('video_analyses')
      .select('*')
      .order('created_at', ascending: false);
});

// ── Page ──────────────────────────────────────────────────────────
class UsageStatsPage extends ConsumerWidget {
  const UsageStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(_usageProvider);
    final user = ref.watch(userProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(user?.isAdmin == true ? 'Utilizzo AI — Admin' : 'Utilizzo AI'),
        backgroundColor: AppTheme.cardColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Aggiorna',
            onPressed: () => ref.invalidate(_usageProvider),
          ),
        ],
      ),
      body: usageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen)),
        error: (e, _) => _ErrorView(error: e.toString(), onRetry: () => ref.invalidate(_usageProvider)),
        data: (data) => _UsageBody(data: data, isAdmin: user?.isAdmin ?? false),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────
class _UsageBody extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool isAdmin;
  const _UsageBody({required this.data, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    int totalTokens = 0;
    double totalCost = 0.0;
    for (final item in data) {
      totalTokens += (item['total_tokens'] as int? ?? 0);
      totalCost += _costForItem(item);
    }

    return CustomScrollView(
      slivers: [
        // ── Summary cards ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Costo stimato',
                        value: '\$${totalCost.toStringAsFixed(3)}',
                        icon: Icons.payments_outlined,
                        color: AppTheme.accentGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Token totali',
                        value: _fmt(totalTokens),
                        icon: Icons.bolt_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Analisi',
                        value: data.length.toString(),
                        icon: Icons.analytics_outlined,
                        color: const Color(0xFF7C4DFF),
                      ),
                    ),
                  ],
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreenDim.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentGreenDim.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.admin_panel_settings_outlined, size: 14, color: AppTheme.accentGreen),
                        SizedBox(width: 8),
                        Text('Visualizzazione admin — tutte le analisi', style: TextStyle(fontSize: 12, color: AppTheme.accentGreen)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Section label ─────────────────────────────────────
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'DETTAGLIO ANALISI',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.4),
            ),
          ),
        ),

        // ── Empty state ───────────────────────────────────────
        if (data.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.analytics_outlined, size: 48, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text('Nessuna analisi ancora', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),

        // ── List ──────────────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _AnalysisRow(item: data[i], index: i),
            childCount: data.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

// ── Row ───────────────────────────────────────────────────────────
class _AnalysisRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  const _AnalysisRow({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(item['created_at'] as String? ?? '');
    final tok = item['total_tokens'] as int? ?? 0;
    final promptTok = item['prompt_tokens'] as int? ?? 0;
    final completionTok = item['completion_tokens'] as int? ?? 0;
    final cost = _costForItem(item);
    final name = item['video_name'] as String? ?? 'Analisi ${index + 1}';
    final model = item['model_name'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.sidebarBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Index badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.sidebarSectionColor,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (date != null)
                        Text(DateFormat('dd/MM/yy HH:mm').format(date), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      if (model.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.sidebarSectionColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            model.replaceAll('gemini-', '').replaceAll('-latest', ''),
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '↑ $promptTok  ↓ $completionTok  tot ${_fmtN(tok)}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            // Cost
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${cost.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accentGreen),
                ),
                Text('${_fmtN(tok)} tok', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtN(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

// ── Stat Card ─────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.sidebarBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Riprova'),
          ),
        ],
      ),
    );
  }
}
