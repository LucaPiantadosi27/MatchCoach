import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';
import 'package:lavagna_tattica/features/matches/data/models/calendar_entry_model.dart';
import 'package:lavagna_tattica/features/matches/data/models/season_model.dart';
import 'package:lavagna_tattica/features/matches/data/repositories/matches_repository.dart';
import 'package:lavagna_tattica/features/matches/providers/matches_providers.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  bool _isImporting = false;

  // ── Import CSV ───────────────────────────────────────────────────
  void _importCsv() {
    final input = html.FileUploadInputElement()..accept = '.csv';
    input.click();
    input.onChange.listen((e) async {
      final file = input.files?.first;
      if (file == null) return;
      setState(() => _isImporting = true);
      final reader = html.FileReader();
      reader.readAsText(file);
      reader.onLoad.listen((_) async {
        try {
          final content = reader.result as String;
          final seasonId = ref.read(selectedSeasonProvider);
          final entries = _parseCsv(content, seasonId);
          await ref.read(matchesRepositoryProvider).importCalendarEntries(entries);
          ref.invalidate(calendarProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${entries.length} giornate importate'), backgroundColor: AppTheme.accentGreenDim),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Errore import: $e'), backgroundColor: AppTheme.errorColor),
            );
          }
        } finally {
          if (mounted) setState(() => _isImporting = false);
        }
      });
    });
  }

  List<CalendarEntryModel> _parseCsv(String content, String? seasonId) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final entries = <CalendarEntryModel>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',').map((c) => c.trim()).toList();
      if (cols.length < 3) continue;
      // Formato: giornata,casa,ospite[,data,luogo]
      entries.add(CalendarEntryModel(
        id: '',
        userId: '',
        seasonId: seasonId,
        matchDay: int.tryParse(cols[0]),
        homeTeam: cols[1],
        awayTeam: cols[2],
        scheduledDate: cols.length > 3 && cols[3].isNotEmpty ? DateTime.tryParse(cols[3]) : null,
        venue: cols.length > 4 ? cols[4] : null,
        createdAt: DateTime.now(),
      ));
    }
    return entries;
  }

  // ── Add entry manually ───────────────────────────────────────────
  void _showAddEntryDialog() {
    showDialog(context: context, builder: (_) => _AddEntryDialog(
      seasonId: ref.read(selectedSeasonProvider),
      onSaved: () => ref.invalidate(calendarProvider),
    ));
  }

  // ── Create season ─────────────────────────────────────────────────
  void _showCreateSeasonDialog() {
    showDialog(context: context, builder: (_) => _CreateSeasonDialog(
      onCreated: () => ref.invalidate(seasonsProvider),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final seasonsAsync = ref.watch(seasonsProvider);
    final selectedSeason = ref.watch(selectedSeasonProvider);
    final calendarAsync = ref.watch(calendarProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Season selector + actions bar ─────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppTheme.cardColor,
            border: Border(bottom: BorderSide(color: AppTheme.sidebarBorderColor)),
          ),
          child: Row(
            children: [
              // Season dropdown
              Expanded(
                child: seasonsAsync.when(
                  loading: () => const SizedBox(height: 36),
                  error: (_, __) => const SizedBox(),
                  data: (seasons) => _SeasonDropdown(
                    seasons: seasons,
                    selectedId: selectedSeason,
                    onChanged: (id) => ref.read(selectedSeasonProvider.notifier).state = id,
                    onCreateNew: _showCreateSeasonDialog,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Import CSV
              _ActionButton(
                icon: Icons.upload_file_rounded,
                label: 'Importa CSV',
                loading: _isImporting,
                onTap: _importCsv,
              ),
              const SizedBox(width: 8),
              // Add manual
              _ActionButton(
                icon: Icons.add_rounded,
                label: 'Aggiungi',
                onTap: _showAddEntryDialog,
                primary: true,
              ),
            ],
          ),
        ),

        // ── CSV format hint ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Formato CSV: giornata, casa, ospite, data (AAAA-MM-GG), luogo',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ),

        // ── Calendar list ─────────────────────────────────────────
        Expanded(
          child: calendarAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen)),
            error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: AppTheme.errorColor))),
            data: (entries) {
              if (entries.isEmpty) {
                return _EmptyCalendar(onAdd: _showAddEntryDialog, onImport: _importCsv);
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: entries.length,
                itemBuilder: (ctx, i) => _CalendarEntryRow(
                  entry: entries[i],
                  onCreateMatch: () => _createMatchFromEntry(entries[i]),
                  onDelete: () => _deleteEntry(entries[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _createMatchFromEntry(CalendarEntryModel entry) {
    context.push('/matches/new', extra: entry);
  }

  Future<void> _deleteEntry(String entryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Elimina giornata', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Sei sicuro?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina', style: TextStyle(color: AppTheme.errorColor))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(matchesRepositoryProvider).deleteCalendarEntry(entryId);
      ref.invalidate(calendarProvider);
    }
  }
}

// ── Widgets ───────────────────────────────────────────────────────

class _SeasonDropdown extends StatelessWidget {
  final List<SeasonModel> seasons;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCreateNew;
  const _SeasonDropdown({required this.seasons, required this.selectedId, required this.onChanged, required this.onCreateNew});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.sidebarSectionColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.sidebarBorderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedId,
          dropdownColor: AppTheme.cardColor,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          hint: const Text('Tutte le stagioni', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          isExpanded: true,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Tutte le stagioni', style: TextStyle(fontSize: 13))),
            ...seasons.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13)))),
            const DropdownMenuItem(value: '__new__', child: Row(
              children: [Icon(Icons.add_rounded, size: 14, color: AppTheme.accentGreen), SizedBox(width: 6),
                Text('Nuova stagione', style: TextStyle(color: AppTheme.accentGreen, fontSize: 13))],
            )),
          ],
          onChanged: (v) {
            if (v == '__new__') { onCreateNew(); return; }
            onChanged(v);
          },
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool loading;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.primary = false, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppTheme.accentGreenDim : AppTheme.sidebarSectionColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              loading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(icon, size: 14, color: primary ? Colors.white : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: primary ? Colors.white : AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarEntryRow extends StatelessWidget {
  final CalendarEntryModel entry;
  final VoidCallback onCreateMatch;
  final VoidCallback onDelete;
  const _CalendarEntryRow({required this.entry, required this.onCreateMatch, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final hasMatch = entry.isLinkedToMatch;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasMatch ? AppTheme.accentGreenDim.withValues(alpha: 0.4) : AppTheme.sidebarBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Match day badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasMatch ? AppTheme.accentGreenDim.withValues(alpha: 0.15) : AppTheme.sidebarSectionColor,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: entry.matchDay != null
                  ? Text('G${entry.matchDay}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: hasMatch ? AppTheme.accentGreen : AppTheme.textSecondary))
                  : const Icon(Icons.sports_soccer_outlined, size: 16, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 12),
            // Teams
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.homeTeam} vs ${entry.awayTeam}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (entry.scheduledDate != null) ...[
                        const Icon(Icons.calendar_today_outlined, size: 11, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(DateFormat('dd/MM/yyyy').format(entry.scheduledDate!),
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        const SizedBox(width: 10),
                      ],
                      if (entry.venue != null) ...[
                        const Icon(Icons.place_outlined, size: 11, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(entry.venue!, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Status + action
            if (hasMatch)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreenDim.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Analizzata', style: TextStyle(fontSize: 11, color: AppTheme.accentGreen)),
              )
            else
              TextButton.icon(
                onPressed: onCreateMatch,
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Crea partita', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7C4DFF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.textMuted),
              onPressed: onDelete,
              tooltip: 'Elimina',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCalendar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onImport;
  const _EmptyCalendar({required this.onAdd, required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month_outlined, size: 52, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text('Nessuna giornata nel calendario', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('Aggiungi manualmente o importa un file CSV', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Importa CSV'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Aggiungi giornata'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Dialogs ───────────────────────────────────────────────────────

class _CreateSeasonDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateSeasonDialog({required this.onCreated});

  @override
  ConsumerState<_CreateSeasonDialog> createState() => _CreateSeasonDialogState();
}

class _CreateSeasonDialogState extends ConsumerState<_CreateSeasonDialog> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('Nuova stagione', style: TextStyle(color: AppTheme.textPrimary)),
      content: TextField(
        controller: _nameCtrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'es. Serie A 2024/25',
          labelText: 'Nome stagione',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        ElevatedButton(
          onPressed: _saving ? null : () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            setState(() => _saving = true);
            await ref.read(matchesRepositoryProvider).createSeason(_nameCtrl.text.trim());
            widget.onCreated();
            if (mounted) Navigator.pop(context);
          },
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Crea'),
        ),
      ],
    );
  }
}

class _AddEntryDialog extends ConsumerStatefulWidget {
  final String? seasonId;
  final VoidCallback onSaved;
  const _AddEntryDialog({required this.seasonId, required this.onSaved});

  @override
  ConsumerState<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends ConsumerState<_AddEntryDialog> {
  final _homeCtrl = TextEditingController();
  final _awayCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();
  DateTime? _selectedDate;
  bool _saving = false;

  @override
  void dispose() {
    _homeCtrl.dispose(); _awayCtrl.dispose();
    _venueCtrl.dispose(); _dayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('Aggiungi giornata', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _homeCtrl,
                    decoration: const InputDecoration(labelText: 'Squadra casa *'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _awayCtrl,
                    decoration: const InputDecoration(labelText: 'Squadra ospite *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Giornata'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (d != null) setState(() => _selectedDate = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Data'),
                      child: Text(
                        _selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : 'Seleziona',
                        style: TextStyle(fontSize: 14, color: _selectedDate != null ? AppTheme.textPrimary : AppTheme.textMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _venueCtrl,
              decoration: const InputDecoration(labelText: 'Luogo (opzionale)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        ElevatedButton(
          onPressed: _saving ? null : () async {
            if (_homeCtrl.text.trim().isEmpty || _awayCtrl.text.trim().isEmpty) return;
            setState(() => _saving = true);
            final entry = CalendarEntryModel(
              id: '', userId: '',
              seasonId: widget.seasonId,
              matchDay: int.tryParse(_dayCtrl.text.trim()),
              homeTeam: _homeCtrl.text.trim(),
              awayTeam: _awayCtrl.text.trim(),
              scheduledDate: _selectedDate,
              venue: _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
              createdAt: DateTime.now(),
            );
            final userId = ref.read(userProvider).valueOrNull?.id ?? '';
            await ref.read(matchesRepositoryProvider).createCalendarEntry(
              CalendarEntryModel(
                id: '', userId: userId,
                seasonId: widget.seasonId,
                matchDay: entry.matchDay,
                homeTeam: entry.homeTeam,
                awayTeam: entry.awayTeam,
                scheduledDate: entry.scheduledDate,
                venue: entry.venue,
                createdAt: entry.createdAt,
              ),
            );
            widget.onSaved();
            if (mounted) Navigator.pop(context);
          },
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salva'),
        ),
      ],
    );
  }
}
