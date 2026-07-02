import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/field_background.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/board_state.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/drawing_path.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/equipment_model.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/board_provider.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/recording_provider.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/schemes_list_page.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/recording_player.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/team_color_dropdown.dart';
import 'package:lavagna_tattica/features/tactical_board/presentation/widgets/equipment_dropdown.dart';

// ─── Colors used throughout the sidebar ───────────────────────────────────────
const _section   = AppTheme.sidebarSectionColor;   // #1A1E26
const _border    = AppTheme.sidebarBorderColor;    // #2D3340
const _accent    = AppTheme.accentGreen;           // #3FB950
const _accentDim = AppTheme.accentGreenDim;        // #238636
const _textPri   = AppTheme.textPrimary;
const _textSec   = AppTheme.textSecondary;
const _textMut   = AppTheme.textMuted;

class SidebarPanel extends ConsumerWidget {
  const SidebarPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBackground = ref.watch(fieldBackgroundProvider);
    final recordingState = ref.watch(recordingProvider);
    final boardState = ref.watch(boardProvider);
    final isNewScheme = ref.watch(isNewSchemeProvider);

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: const BoxDecoration(
        gradient: AppTheme.sidebarGradient,
        border: Border(right: BorderSide(color: _border, width: 1)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── REGISTRA (solo nuovi schemi)
            if (isNewScheme) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildRecordingButton(ref, recordingState),
              ),
              const SizedBox(height: 12),
              if (boardState.recording != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildRecordingPlayer(),
                ),
              if (boardState.recording != null)
                const SizedBox(height: 12),
              const _SidebarDivider(),
              const SizedBox(height: 12),
            ],
            // ── CAMPO
            _buildSection(
              title: 'CAMPO',
              icon: Icons.sports_soccer_rounded,
              child: _buildBackgroundGrid(ref, currentBackground),
            ),
            const _SidebarDivider(),
            // ── VISTA CAMPO
            _buildSection(
              title: 'VISTA CAMPO',
              icon: Icons.crop_rounded,
              child: _buildFieldViewModeSelector(ref),
            ),
            const _SidebarDivider(),
            // ── MODALITÀ
            _buildSection(
              title: 'MODALITÀ',
              icon: Icons.touch_app_rounded,
              child: Column(
                children: [
                  _buildModeButton(ref, InteractionMode.move, 'Movimento', Icons.pan_tool_rounded),
                  const SizedBox(height: 6),
                  _buildModeButton(ref, InteractionMode.draw, 'Disegna', Icons.edit_rounded),
                  const SizedBox(height: 6),
                  _buildModeButton(ref, InteractionMode.removeEquipment, 'Rimuovi attrezzature', Icons.delete_outline_rounded),
                ],
              ),
            ),
            // ── STILE LINEA (solo in draw mode)
            if (ref.watch(interactionModeProvider) == InteractionMode.draw) ...[
              const _SidebarDivider(),
              _buildSection(
                title: 'STILE LINEA',
                icon: Icons.gesture_rounded,
                child: Column(
                  children: [
                    _buildLineStyleGrid(ref),
                    const SizedBox(height: 10),
                    _buildStrokeWidthSlider(ref),
                    const SizedBox(height: 6),
                    _buildArrowToggle(ref),
                  ],
                ),
              ),
            ],
            const _SidebarDivider(),
            // ── COLORI PENNARELLO
            _buildSection(
              title: 'COLORI PENNARELLO',
              icon: Icons.palette_rounded,
              child: _buildColorPicker(ref),
            ),
            const _SidebarDivider(),
            // ── COLORI SQUADRE
            _buildSection(
              title: 'COLORI SQUADRE',
              icon: Icons.groups_rounded,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _showTeamColorDialog(context, ref, true),
                    child: const TeamColorDropdown(isTeam1: true),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showTeamColorDialog(context, ref, false),
                    child: const TeamColorDropdown(isTeam1: false),
                  ),
                ],
              ),
            ),
            const _SidebarDivider(),
            // ── ATTREZZATURE
            _buildSection(
              title: 'ATTREZZATURE',
              icon: Icons.sports_rounded,
              child: GestureDetector(
                onTap: () => _showEquipmentDialog(context),
                child: const EquipmentDropdown(),
              ),
            ),
            const _SidebarDivider(),
            // ── IMPOSTAZIONI
            _buildSection(
              title: 'IMPOSTAZIONI',
              icon: Icons.settings_rounded,
              child: _buildGridToggle(ref),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Recording Button ──────────────────────────────────────────────────────
  Widget _buildRecordingButton(WidgetRef ref, RecordingState recordingState) {
    final isRecording = recordingState == RecordingState.recording;
    final boardState = ref.watch(boardProvider);
    final hasRecording = boardState.recording != null;
    final stepCount = ref.watch(recordingStepCountProvider);

    if (isRecording) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bottone Aggiungi Step
          GestureDetector(
            onTap: () {
              ref.read(recordingProvider.notifier).addStep();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF9A826), Color(0xFFF57C00)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF9A826).withAlpha(100),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'AGGIUNGI STEP ${stepCount + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Bottone Termina Registrazione
          GestureDetector(
            onTap: () => _handleStopRecordingAction(ref.context, ref, boardState),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB71C1C).withAlpha(128),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.stop_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'TERMINA REGISTRAZIONE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final List<Color> gradientColors = hasRecording
            ? [const Color(0xFF388E3C), const Color(0xFF1B5E20)]
            : [const Color(0xFF1565C0), const Color(0xFF0D47A1)];

    return GestureDetector(
      onTap: () {
        ref.read(recordingProvider.notifier).startRecording();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withAlpha(76),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasRecording ? Icons.check_circle_rounded : Icons.fiber_manual_record_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                hasRecording ? 'REGISTRAZIONE SALVATA' : 'AVVIA REGISTRAZIONE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStopRecordingAction(BuildContext context, WidgetRef ref, BoardState boardState) async {
    final recording = ref.read(recordingProvider.notifier).stopRecording();
    final updatedBoardState = boardState.copyWith(recording: recording);
    ref.read(boardProvider.notifier).updateState(updatedBoardState);

    if (!context.mounted) return;

    final TextEditingController nameController = TextEditingController(
      text: 'Schema ${DateTime.now().day}/${DateTime.now().month} ${DateTime.now().hour}:${DateTime.now().minute}',
    );

    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColorElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _border),
        ),
        title: const Text('Salva Registrazione',
            style: TextStyle(color: _textPri, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✅ Registrazione: ${recording.duration.toStringAsFixed(1)}s',
              style: const TextStyle(color: _accent, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameController,
              style: const TextStyle(color: _textPri),
              decoration: const InputDecoration(labelText: 'Nome schema'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla', style: TextStyle(color: _textSec)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            style: ElevatedButton.styleFrom(backgroundColor: _accentDim),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && context.mounted) {
      _saveSchemeWithRecording(context, ref, name, updatedBoardState);
    } else {
      // Clear recording if aborted
      ref.read(boardProvider.notifier).clearRecording();
    }
  }

  Widget _buildRecordingPlayer() {
    return Container(
      decoration: BoxDecoration(
        color: _section,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(10),
      child: const RecordingPlayer(),
    );
  }

  // ─── Section wrapper ───────────────────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: _accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _textSec,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // ─── Background grid ───────────────────────────────────────────────────────
  Widget _buildBackgroundGrid(WidgetRef ref, FieldBackground currentBackground) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: FieldBackground.all.map((bg) {
        final isSelected = currentBackground.type == bg.type;
        return GestureDetector(
          onTap: () => ref.read(fieldBackgroundProvider.notifier).state = bg,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52,
            height: 44,
            decoration: BoxDecoration(
              color: bg.previewColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? _accent : _border,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: _accent.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(bg.icon, size: 15, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(height: 2),
                Text(
                  bg.displayName,
                  style: TextStyle(
                    fontSize: 7,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Field view mode ───────────────────────────────────────────────────────
  Widget _buildFieldViewModeSelector(WidgetRef ref) {
    final currentMode = ref.watch(fieldViewModeProvider);
    return Row(
      children: [
        _buildViewModeBtn(ref, FieldViewMode.fullField, 'Intero', Icons.rectangle_outlined, currentMode),
        const SizedBox(width: 6),
        _buildViewModeBtn(ref, FieldViewMode.halfFieldLeft, 'Metà SX', Icons.vertical_split, currentMode),
        const SizedBox(width: 6),
        _buildViewModeBtn(ref, FieldViewMode.halfFieldRight, 'Metà DX', Icons.vertical_split, currentMode, flip: true),
      ],
    );
  }

  Widget _buildViewModeBtn(WidgetRef ref, FieldViewMode mode, String label, IconData icon, FieldViewMode current, {bool flip = false}) {
    final isSelected = current == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(fieldViewModeProvider.notifier).state = mode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? _accentDim.withValues(alpha: 0.25) : _section,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? _accent : _border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Transform(
                alignment: Alignment.center,
                transform: flip ? Matrix4.rotationY(3.14159) : Matrix4.identity(),
                child: Icon(icon, size: 16, color: isSelected ? _accent : _textSec),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? _accent : _textSec,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Mode button ───────────────────────────────────────────────────────────
  Widget _buildModeButton(WidgetRef ref, InteractionMode mode, String label, IconData icon) {
    final currentMode = ref.watch(interactionModeProvider);
    final isSelected = currentMode == mode;
    return GestureDetector(
      onTap: () => ref.read(interactionModeProvider.notifier).state = mode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _accentDim.withValues(alpha: 0.2) : _section,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _accent : _border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? _accent : _textSec),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? _textPri : _textSec,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _accent),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Line style grid ───────────────────────────────────────────────────────
  Widget _buildLineStyleGrid(WidgetRef ref) {
    final selectedStyle = ref.watch(selectedLineStyleProvider);
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: LineStyle.values.map((style) {
        final isSelected = selectedStyle == style;
        return GestureDetector(
          onTap: () => ref.read(selectedLineStyleProvider.notifier).state = style,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 52,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? _accentDim.withValues(alpha: 0.2) : _section,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: isSelected ? _accent : _border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomPaint(
                  size: const Size(32, 8),
                  painter: _SidebarLinePreviewPainter(
                    style,
                    isSelected ? _accent : _textSec,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _lineStyleLabel(style),
                  style: TextStyle(
                    fontSize: 7,
                    color: isSelected ? _accent : _textSec,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Stroke width slider ───────────────────────────────────────────────────
  Widget _buildStrokeWidthSlider(WidgetRef ref) {
    final strokeWidth = ref.watch(selectedStrokeWidthProvider);
    return Row(
      children: [
        const Icon(Icons.line_weight_rounded, size: 14, color: _textSec),
        const SizedBox(width: 6),
        Text(
          '${strokeWidth.toInt()}px',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _textSec),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: _accent,
              inactiveTrackColor: _border,
              thumbColor: _accent,
              overlayColor: _accent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: strokeWidth,
              min: 1.0,
              max: 10.0,
              divisions: 9,
              onChanged: (v) => ref.read(selectedStrokeWidthProvider.notifier).state = v,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Arrow toggle ──────────────────────────────────────────────────────────
  Widget _buildArrowToggle(WidgetRef ref) {
    final hasArrow = ref.watch(hasArrowProvider);
    return GestureDetector(
      onTap: () => ref.read(hasArrowProvider.notifier).state = !hasArrow,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hasArrow ? _accentDim.withValues(alpha: 0.15) : _section,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasArrow ? _accent : _border),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_forward_rounded, size: 15, color: hasArrow ? _accent : _textSec),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Freccia direzionale',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: hasArrow ? FontWeight.w600 : FontWeight.w400,
                  color: hasArrow ? _textPri : _textSec,
                ),
              ),
            ),
            if (hasArrow)
              const Icon(Icons.check_rounded, size: 13, color: _accent),
          ],
        ),
      ),
    );
  }

  // ─── Color picker ──────────────────────────────────────────────────────────
  Widget _buildColorPicker(WidgetRef ref) {
    final currentColor = ref.watch(selectedColorProvider);
    final colors = [Colors.white, Colors.red, Colors.blue, Colors.yellow, Colors.green, Colors.purple];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((color) {
        final isSelected = currentColor == color;
        return GestureDetector(
          onTap: () => ref.read(selectedColorProvider.notifier).state = color,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isSelected ? 38 : 34,
            height: isSelected ? 38 : 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? _accent : _border,
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 1)]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check_rounded,
                    color: (color == Colors.white || color == Colors.yellow) ? Colors.black : Colors.white,
                    size: 18,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  // ─── Equipment grid ────────────────────────────────────────────────────────
  // ignore: unused_element
  Widget _buildEquipmentGrid(WidgetRef ref) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: EquipmentType.values.map((type) {
        return GestureDetector(
          onTap: () => ref.read(boardProvider.notifier).addEquipment(type),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _section,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildEquipmentIcon(type),
                const SizedBox(height: 2),
                Text(
                  type.label,
                  style: const TextStyle(fontSize: 7, color: _textSec),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEquipmentIcon(EquipmentType type) {
    switch (type) {
      case EquipmentType.cone:
        return CustomPaint(size: const Size(24, 24), painter: _ConeIconPainter());
      case EquipmentType.obstacle:
        return Container(
          width: 20, height: 8,
          decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(2)),
        );
      case EquipmentType.ladder:
        return const Icon(Icons.stairs, size: 20, color: Color(0xFFFDD835));
      case EquipmentType.miniGoal:
        return Container(
          width: 20, height: 14,
          decoration: BoxDecoration(border: Border.all(color: _textSec, width: 2), borderRadius: BorderRadius.circular(2)),
        );
      case EquipmentType.pole:
        return Container(
          width: 6, height: 20,
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(3)),
        );
      case EquipmentType.yellowCard:
        return Container(
          width: 12, height: 16,
          decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(2)),
        );
      case EquipmentType.redCard:
        return Container(
          width: 12, height: 16,
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(2)),
        );
      case EquipmentType.topViewPlayer:
        return Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2E7D32),
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      case EquipmentType.mannequin:
        return const Icon(Icons.accessibility_new, size: 20, color: _textSec);
    }
  }

  // ─── Grid toggle ───────────────────────────────────────────────────────────
  Widget _buildGridToggle(WidgetRef ref) {
    final showGrid = ref.watch(showGridProvider);
    return GestureDetector(
      onTap: () => ref.read(showGridProvider.notifier).state = !showGrid,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: showGrid ? _accentDim.withValues(alpha: 0.15) : _section,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: showGrid ? _accent : _border),
        ),
        child: Row(
          children: [
            Icon(Icons.grid_on_rounded, size: 16, color: showGrid ? _accent : _textSec),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Griglia allineamento',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: showGrid ? FontWeight.w600 : FontWeight.w400,
                  color: showGrid ? _textPri : _textSec,
                ),
              ),
            ),
            Switch(
              value: showGrid,
              onChanged: (v) => ref.read(showGridProvider.notifier).state = v,
              activeThumbColor: _accent,
              inactiveThumbColor: _textMut,
              inactiveTrackColor: _border,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  String _lineStyleLabel(LineStyle style) {
    switch (style) {
      case LineStyle.solid:        return 'Solida';
      case LineStyle.dashed:       return 'Tratteg.';
      case LineStyle.dotted:       return 'Punteg.';
      case LineStyle.dashDot:      return '— •';
      case LineStyle.dashDotDot:   return '— ••';
      case LineStyle.wavy:         return 'Onda';
      case LineStyle.arrow:        return 'Freccia';
      case LineStyle.doubleArrow:  return '⇄';
      case LineStyle.curved:       return 'Curva';
      case LineStyle.zigzag:       return 'Zigzag';
      case LineStyle.thick:        return 'Larga';
      case LineStyle.highlighter:  return 'Evid.';
    }
  }

  Future<void> _saveSchemeWithRecording(
    BuildContext context,
    WidgetRef ref,
    String name,
    BoardState boardState,
  ) async {
    final user = ref.read(userProvider).valueOrNull;
    if (user == null || boardState.recording == null) return;
    try {
      await ref.read(recordingRepositoryProvider).saveRecording(
        userId: user.id,
        name: name,
        recording: boardState.recording!,
      );
      await ref.read(userProvider.notifier).incrementSchemesCount();
      ref.invalidate(userRecordingsProvider);
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardColorElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _border),
            ),
            title: const Text('Operazione completata', style: TextStyle(color: _textPri, fontSize: 16)),
            content: const Text(
              'Registrazione salvata con successo!',
              style: TextStyle(color: _textSec, fontSize: 14)
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: _accentDim),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        ref.read(boardProvider.notifier).clearRecording();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel salvataggio: $e')),
        );
      }
    }
  }

  // Show team color picker dialog
  void _showTeamColorDialog(BuildContext context, WidgetRef ref, bool isTeam1) {
    showDialog(
      context: context,
      builder: (context) => TeamColorPickerDialog(isTeam1: isTeam1),
    );
  }

  // Show equipment picker dialog
  void _showEquipmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EquipmentPickerDialog(),
    );
  }
}

// ─── Divider ──────────────────────────────────────────────────────────────────
class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: _border,
    );
  }
}

// ─── Line preview painter ─────────────────────────────────────────────────────
class _SidebarLinePreviewPainter extends CustomPainter {
  final LineStyle style;
  final Color color;
  _SidebarLinePreviewPainter(this.style, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;

    switch (style) {
      case LineStyle.solid:
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      case LineStyle.dashed:
        double x = 0;
        while (x < size.width) {
          canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(0, size.width), y), paint);
          x += 6;
        }
      case LineStyle.dotted:
        final dp = Paint()..color = color..style = PaintingStyle.fill;
        for (double x = 1; x < size.width; x += 4) {
          canvas.drawCircle(Offset(x, y), 1, dp);
        }
      case LineStyle.dashDot:
        canvas.drawLine(Offset(0, y), Offset(8, y), paint);
        canvas.drawCircle(Offset(12, y), 1, Paint()..color = color..style = PaintingStyle.fill);
        canvas.drawLine(Offset(16, y), Offset(24, y), paint);
        canvas.drawCircle(Offset(28, y), 1, Paint()..color = color..style = PaintingStyle.fill);
      case LineStyle.dashDotDot:
        canvas.drawLine(Offset(0, y), Offset(6, y), paint);
        canvas.drawCircle(Offset(9, y), 1, Paint()..color = color..style = PaintingStyle.fill);
        canvas.drawCircle(Offset(13, y), 1, Paint()..color = color..style = PaintingStyle.fill);
        canvas.drawLine(Offset(16, y), Offset(22, y), paint);
      case LineStyle.wavy:
        final path = Path()..moveTo(0, y);
        for (double x = 0; x < size.width; x += 0.5) {
          path.lineTo(x, y + 2.5 * _sin(x / 3.5));
        }
        canvas.drawPath(path, paint);
      case LineStyle.arrow:
        canvas.drawLine(Offset(0, y), Offset(size.width - 3, y), paint);
        final arrow = Path()..moveTo(size.width, y)..lineTo(size.width - 5, y - 3)..lineTo(size.width - 5, y + 3)..close();
        canvas.drawPath(arrow, Paint()..color = color..style = PaintingStyle.fill);
      case LineStyle.doubleArrow:
        canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), paint);
        final fp = Paint()..color = color..style = PaintingStyle.fill;
        canvas.drawPath(Path()..moveTo(size.width, y)..lineTo(size.width - 5, y - 3)..lineTo(size.width - 5, y + 3)..close(), fp);
        canvas.drawPath(Path()..moveTo(0, y)..lineTo(5, y - 3)..lineTo(5, y + 3)..close(), fp);
      case LineStyle.curved:
        canvas.drawPath(Path()..moveTo(0, y + 2)..quadraticBezierTo(size.width / 2, y - 4, size.width, y + 2), paint);
      case LineStyle.zigzag:
        final path = Path()..moveTo(0, y);
        for (double x = 0; x < size.width; x += 5) { path.lineTo(x + 2.5, y - 3); path.lineTo(x + 5, y + 3); }
        canvas.drawPath(path, paint);
      case LineStyle.thick:
        paint.strokeWidth = 3.5;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      case LineStyle.highlighter:
        paint.strokeWidth = 5;
        paint.color = color.withValues(alpha: 0.4);
        paint.strokeCap = StrokeCap.butt;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  double _sin(double x) {
    x = x % (2 * 3.14159) - 3.14159;
    return x - (x * x * x) / 6;
  }

  @override
  bool shouldRepaint(covariant _SidebarLinePreviewPainter old) => old.style != style || old.color != color;
}

// ─── Cone icon ────────────────────────────────────────────────────────────────
class _ConeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 2)
      ..lineTo(size.width - 4, size.height - 2)
      ..lineTo(4, size.height - 2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.orange.shade300, Colors.orange.shade700],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.orange.shade900,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
