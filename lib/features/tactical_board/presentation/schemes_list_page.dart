import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/saved_recording.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/saved_snapshot.dart';
import 'package:lavagna_tattica/features/tactical_board/data/recording_repository.dart';
import 'package:lavagna_tattica/features/tactical_board/data/snapshot_repository.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/board_provider.dart';

final recordingRepositoryProvider = Provider((ref) => RecordingRepository());
final snapshotRepositoryProvider = Provider((ref) => SnapshotRepository());

final userRecordingsProvider = FutureProvider<List<SavedRecording>>((ref) async {
  final user = ref.watch(userProvider).valueOrNull;
  if (user == null) return [];
  return ref.read(recordingRepositoryProvider).getUserRecordings(user.id);
});

final userSnapshotsProvider = FutureProvider<List<SavedSnapshot>>((ref) async {
  final user = ref.watch(userProvider).valueOrNull;
  if (user == null) return [];
  return ref.read(snapshotRepositoryProvider).getUserSnapshots(user.id);
});

class SchemesListPage extends ConsumerWidget {
  const SchemesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Schemi'),
          backgroundColor: AppTheme.cardColor,
          surfaceTintColor: Colors.transparent,
          bottom: const TabBar(
            indicatorColor: Color(0xFF9575CD),
            indicatorWeight: 3,
            labelColor: Color(0xFF9575CD),
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              Tab(icon: Icon(Icons.video_library_rounded, size: 18), text: 'Registrazioni'),
              Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Snapshot'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RecordingsTab(ref: ref, context: context),
            _SnapshotsTab(ref: ref, context: context),
          ],
        ),
        floatingActionButton: _buildFab(context, ref),
      ),
    );
  }

  Widget _buildFab(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF512DA8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x557C4DFF),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          ref.read(isNewSchemeProvider.notifier).state = true;
          ref.read(boardProvider.notifier).reset();
          context.go('/board');
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Nuova Registrazione',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

}

// ── Recordings Tab ────────────────────────────────────────────────
class _RecordingsTab extends ConsumerWidget {
  final WidgetRef ref;
  final BuildContext context;
  const _RecordingsTab({required this.ref, required this.context});

  @override
  Widget build(BuildContext ctx, WidgetRef r) {
    final recordingsAsync = r.watch(userRecordingsProvider);
    return recordingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9575CD))),
      error: (err, _) => Center(child: Text('Errore: $err', style: const TextStyle(color: AppTheme.errorColor))),
      data: (recordings) {
        if (recordings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.video_library_rounded, size: 52, color: Color(0xFF9575CD)),
                ),
                const SizedBox(height: 20),
                const Text('Nessuna registrazione', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                const Text('Vai alla lavagna e premi REC per iniziare', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: recordings.length,
          itemBuilder: (_, i) => _RecordingCard(
            recording: recordings[i],
            onDelete: () async {
              final confirm = await showDialog<bool>(
                context: ctx,
                builder: (c) => AlertDialog(
                  backgroundColor: AppTheme.cardColorElevated,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTheme.sidebarBorderColor)),
                  title: const Text('Elimina Registrazione', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                  content: Text('Vuoi eliminare "${recordings[i].name}"?', style: const TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary))),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Elimina', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w600))),
                  ],
                ),
              );
              if (confirm == true) {
                await r.read(recordingRepositoryProvider).deleteRecording(recordings[i].id);
                r.invalidate(userRecordingsProvider);
              }
            },
          ),
        );
      },
    );
  }
}

// ── Snapshots Tab ────────────────────────────────────────────────
class _SnapshotsTab extends ConsumerWidget {
  final WidgetRef ref;
  final BuildContext context;
  const _SnapshotsTab({required this.ref, required this.context});

  @override
  Widget build(BuildContext ctx, WidgetRef r) {
    final snapshotsAsync = r.watch(userSnapshotsProvider);
    return snapshotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9575CD))),
      error: (err, _) => Center(child: Text('Errore: $err', style: const TextStyle(color: AppTheme.errorColor))),
      data: (snapshots) {
        if (snapshots.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.photo_library_rounded, size: 52, color: Color(0xFF9575CD)),
                ),
                const SizedBox(height: 20),
                const Text('Nessuno snapshot', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                const Text('Usa il tasto 📷 sulla lavagna\nper catturare la posizione delle pedine', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          );
        }
        return LayoutBuilder(
          builder: (_, constraints) {
            final isWide = constraints.maxWidth > 600;
            final cols = isWide ? 3 : 2;
            // Cards compatte: immagine + riga nome sotto
            final aspectRatio = isWide ? 1.2 : 1.0;
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: aspectRatio,
              ),
              itemCount: snapshots.length,
              itemBuilder: (_, i) => _SnapshotCard(
                snapshot: snapshots[i],
                onTap: () => _showSnapshotDetail(ctx, snapshots[i]),
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      backgroundColor: AppTheme.cardColorElevated,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTheme.sidebarBorderColor)),
                      title: const Text('Elimina Snapshot', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                      content: Text('Vuoi eliminare "${snapshots[i].name}"?', style: const TextStyle(color: AppTheme.textSecondary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary))),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Elimina', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await r.read(snapshotRepositoryProvider).deleteSnapshot(snapshots[i].id);
                    r.invalidate(userSnapshotsProvider);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showSnapshotDetail(BuildContext context, SavedSnapshot snapshot) {
    // Create blob + register view factory for the dialog
    final bytes = base64Decode(snapshot.imageBase64);
    final blob = html.Blob([bytes], 'image/png');
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    final viewType = 'snapshot-detail-${snapshot.id}';
    
    try {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        return html.ImageElement()
          ..src = blobUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.borderRadius = '0 0 16px 16px';
      });
    } catch (_) {}
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.sidebarBorderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.photo_rounded, size: 18, color: Color(0xFF9575CD)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(snapshot.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      snapshot.createdAt.toLocal().toString().substring(0, 16),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                ),
                // Image via HtmlElementView
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: HtmlElementView(viewType: viewType),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ); // NOTE: blob URL not revoked - browser GC handles it
  }
}

// ── Snapshot Card ────────────────────────────────────────────────
class _SnapshotCard extends StatefulWidget {
  final SavedSnapshot snapshot;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  const _SnapshotCard({required this.snapshot, required this.onDelete, required this.onTap});

  @override
  State<_SnapshotCard> createState() => _SnapshotCardState();
}

class _SnapshotCardState extends State<_SnapshotCard> {
  String? _blobUrl;
  String? _viewType;

  @override
  void initState() {
    super.initState();
    _createBlobUrl();
  }

  void _createBlobUrl() {
    try {
      debugPrint('🔄 Creating blob for ${widget.snapshot.name}...');
      final bytes = base64Decode(widget.snapshot.imageBase64);
      debugPrint('📦 Decoded ${bytes.length} bytes');
      
      final blob = html.Blob([bytes], 'image/png');
      _blobUrl = html.Url.createObjectUrlFromBlob(blob);
      // Use unique key per instance to avoid re-registration conflicts
      _viewType = 'snapshot-${widget.snapshot.id}-${DateTime.now().microsecondsSinceEpoch}';
      
      final capturedUrl = _blobUrl!;
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType!,
        (int viewId) {
          return html.ImageElement()
            ..src = capturedUrl
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'cover';
        },
      );
      
      debugPrint('✅ Registered viewType: $_viewType');
      if (mounted) setState(() {});
    } catch (e, stack) {
      debugPrint('❌ Failed to create blob URL: $e');
      debugPrint('Stack: $stack');
    }
  }

  @override
  void dispose() {
    // NOTE: do NOT revoke blob URL here - HtmlElementView loads it asynchronously
    // and revoking causes ERR_FILE_NOT_FOUND. Let the browser GC handle cleanup.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.sidebarBorderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview area (takes most space)
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _viewType == null
                      ? Container(
                          color: AppTheme.surfaceColor,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9575CD)),
                          ),
                        )
                      : HtmlElementView(viewType: _viewType!),
                  // Transparent overlay to capture taps over HtmlElementView
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: widget.onTap,
                      behavior: HitTestBehavior.translucent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
            // Name + delete row (pure Flutter, tap works natively)
            GestureDetector(
              onTap: widget.onTap,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border(top: BorderSide(color: AppTheme.sidebarBorderColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.snapshot.name,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onDelete,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recording Card ────────────────────────────────────────────────
class _RecordingCard extends StatelessWidget {
  final SavedRecording recording;
  final VoidCallback onDelete;

  const _RecordingCard({required this.recording, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.sidebarBorderColor),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => context.go('/recording/${recording.id}'),
            borderRadius: BorderRadius.circular(12),
            splashColor:
                const Color(0xFF7C4DFF).withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // ── Thumb
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C4DFF), Color(0xFF512DA8)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_circle_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  // ── Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recording.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 11, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              recording.createdAt.toLocal().toString().split('.')[0],
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Duration chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded,
                            size: 12, color: Color(0xFF9575CD)),
                        const SizedBox(width: 3),
                        Text(
                          '${recording.recording.duration.toStringAsFixed(1)}s',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9575CD),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Delete
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppTheme.textMuted),
                    onPressed: onDelete,
                    tooltip: 'Elimina',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
