import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/schemes_list_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Home'),
        backgroundColor: AppTheme.cardColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentGreen),
        ),
        error: (error, stack) => _buildError(context, ref, error),
        data: (user) {
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accentGreen),
            );
          }
          return _buildBody(context, ref, user);
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text('Errore: $error',
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(userProvider.notifier).refreshUser(),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, user) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── User card
            _buildUserCard(context, user),
            const SizedBox(height: 28),
            // ── Section title
            const Row(
              children: [
                Icon(Icons.grid_view_rounded, size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 8),
                Text(
                  'ACCESSO RAPIDO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Action cards
            _ActionCard(
              icon: Icons.dashboard_rounded,
              title: 'Lavagna Tattica',
              subtitle: 'Crea un nuovo schema',
              accentColor: AppTheme.accentGreen,
              onTap: () => context.go('/board'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.video_library_rounded,
              title: 'Registrazioni salvate',
              subtitle: '',
              accentColor: const Color(0xFF7C4DFF),
              onTap: () => context.go('/schemes'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.videocam_rounded,
              title: 'Analisi Video',
              subtitle: 'Analizza automaticamente le tue partite',
              accentColor: Colors.orange,
              locked: false,
              onTap: () => context.go('/video'),
            ),
            const SizedBox(height: 12),
            if (user.isAdmin) ...[
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.monetization_on_rounded,
                title: 'Controllo Costi AI',
                subtitle: 'Monitoraggio dell\'utilizzo e dei costi API',
                accentColor: Colors.teal,
                locked: false,
                onTap: () => context.go('/usage'),
              ),
            ],
            const SizedBox(height: 24),
            // ── Snapshots section
            _SnapshotPreviewSection(ref: ref, context: context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, user) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.sidebarBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF388E3C), Color(0xFF1B5E20)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGreen.withValues(alpha: 0.3),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 26, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      _buildBadge(user),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: AppTheme.sidebarBorderColor,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Registrazioni salvate',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                Row(
                  children: [
                    Text(
                      user.isPremium
                          ? '${user.schemesCount}'
                          : '${user.schemesCount}/10',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: user.canSaveScheme
                            ? AppTheme.accentGreen
                            : AppTheme.errorColor,
                      ),
                    ),
                    if (user.isPremium)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('∞',
                            style: TextStyle(
                                color: AppTheme.accentGreen,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(user) {
    final Color badgeColor = user.isAdmin
        ? const Color(0xFFE53935)
        : user.isPremium
            ? Colors.amber
            : AppTheme.textMuted;
    final String label = user.isAdmin
        ? '🛡️ ADMIN'
        : user.isPremium
            ? '⭐ Premium'
            : 'Free';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: badgeColor,
        ),
      ),
    );
  }
}

// ── Snapshot Preview Section ────────────────────────────────────
class _SnapshotPreviewSection extends ConsumerWidget {
  final WidgetRef ref;
  final BuildContext context;
  const _SnapshotPreviewSection({required this.ref, required this.context});

  @override
  Widget build(BuildContext ctx, WidgetRef r) {
    final snapshotsAsync = r.watch(userSnapshotsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Icon(Icons.photo_library_rounded, size: 16, color: Color(0xFF9575CD)),
            const SizedBox(width: 8),
            const Text(
              'SNAPSHOT RECENTI',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 1.4),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.go('/schemes'),
              child: const Row(
                children: [
                  Text('Vedi tutti', style: TextStyle(fontSize: 12, color: Color(0xFF9575CD), fontWeight: FontWeight.w600)),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF9575CD)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        snapshotsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(color: Color(0xFF9575CD), strokeWidth: 2),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (snapshots) {
            if (snapshots.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.sidebarBorderColor),
                ),
                child: Column(
                  children: [
                    Icon(Icons.photo_library_outlined, size: 36, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    const Text('Nessuno snapshot ancora', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('Premi 📷 sulla lavagna per catturarne uno', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              );
            }

            final recent = snapshots.take(4).toList();
            return SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length + (snapshots.length > 4 ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  if (i == recent.length) {
                    // "see all" tile
                    return GestureDetector(
                      onTap: () => context.go('/schemes'),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF9575CD).withValues(alpha: 0.4)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_view_rounded, color: Color(0xFF9575CD), size: 28),
                            SizedBox(height: 8),
                            Text('Tutti gli\nsnapshot', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF9575CD), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  }

                  final snap = recent[i];
                  return _SnapshotThumb(snap: snap, onTap: () => context.go('/schemes'));
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Snapshot Thumb ───────────────────────────────────────────────
class _SnapshotThumb extends StatefulWidget {
  final dynamic snap;
  final VoidCallback onTap;
  const _SnapshotThumb({required this.snap, required this.onTap});

  @override
  State<_SnapshotThumb> createState() => _SnapshotThumbState();
}

class _SnapshotThumbState extends State<_SnapshotThumb> {
  String? _viewType;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    try {
      final Uint8List bytes = base64Decode(widget.snap.imageBase64 as String);
      final blob = html.Blob([bytes], 'image/png');
      _blobUrl = html.Url.createObjectUrlFromBlob(blob);
      _viewType = 'home-snap-${widget.snap.id}-${DateTime.now().microsecondsSinceEpoch}';
      final capturedUrl = _blobUrl!;
      ui_web.platformViewRegistry.registerViewFactory(_viewType!, (int _) {
        return html.ImageElement()
          ..src = capturedUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover';
      });
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ SnapshotThumb init error: $e');
    }
  }

  @override
  void dispose() {
    // NOTE: do NOT revoke blob URL here - HtmlElementView loads it asynchronously
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.sidebarBorderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _viewType == null
                  ? Container(
                      color: AppTheme.surfaceColor,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9575CD)),
                      ),
                    )
                  : HtmlElementView(viewType: _viewType!),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
              color: AppTheme.surfaceColor,
              child: Text(
                widget.snap.name as String,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action Card ─────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  final bool locked;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.sidebarBorderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: accentColor.withValues(alpha: 0.08),
          highlightColor: accentColor.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Accent left bar
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: locked
                        ? AppTheme.textMuted
                        : accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (locked ? AppTheme.textMuted : accentColor)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: locked ? AppTheme.textMuted : accentColor,
                  ),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: locked
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: locked ? AppTheme.textMuted : AppTheme.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
