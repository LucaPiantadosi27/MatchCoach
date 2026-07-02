import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/team_colors_provider.dart';

class TeamColorDropdown extends ConsumerWidget {
  final bool isTeam1;
  
  const TeamColorDropdown({
    super.key,
    required this.isTeam1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentColor = isTeam1
        ? ref.watch(team1ColorProvider)
        : ref.watch(team2ColorProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.sidebarBorderColor),
      ),
      child: Row(
        children: [
          // Color preview
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: currentColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          // Label
          Text(
            isTeam1 ? 'Squadra 1' : 'Squadra 2',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          // Dropdown arrow
          const Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

class TeamColorPickerDialog extends ConsumerStatefulWidget {
  final bool isTeam1;
  
  const TeamColorPickerDialog({
    super.key,
    required this.isTeam1,
  });

  @override
  ConsumerState<TeamColorPickerDialog> createState() => _TeamColorPickerDialogState();
}

class _TeamColorPickerDialogState extends ConsumerState<TeamColorPickerDialog> {
  bool _showCustomPicker = false;
  double _red = 255;
  double _green = 0;
  double _blue = 0;

  @override
  Widget build(BuildContext context) {
    final currentColor = widget.isTeam1
        ? ref.watch(team1ColorProvider)
        : ref.watch(team2ColorProvider);

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: currentColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isTeam1 ? 'Colore Squadra 1' : 'Colore Squadra 2',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        PredefinedColors.getColorName(currentColor),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Custom RGB picker toggle
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.sidebarBorderColor),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showCustomPicker = !_showCustomPicker;
                    if (_showCustomPicker) {
                      _red = (currentColor.r * 255.0).roundToDouble();
                      _green = (currentColor.g * 255.0).roundToDouble();
                      _blue = (currentColor.b * 255.0).roundToDouble();
                    }
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      _showCustomPicker ? Icons.palette : Icons.palette_outlined,
                      size: 20,
                      color: _showCustomPicker ? AppTheme.accentGreen : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Colore personalizzato RGB',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showCustomPicker ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            
            // Custom RGB picker
            if (_showCustomPicker) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.sidebarBorderColor),
                ),
                child: Column(
                  children: [
                    _buildRGBSlider('R', _red, Colors.red, (value) {
                      setState(() => _red = value);
                      _updateCustomColor();
                    }),
                    const SizedBox(height: 12),
                    _buildRGBSlider('G', _green, Colors.green, (value) {
                      setState(() => _green = value);
                      _updateCustomColor();
                    }),
                    const SizedBox(height: 12),
                    _buildRGBSlider('B', _blue, Colors.blue, (value) {
                      setState(() => _blue = value);
                      _updateCustomColor();
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Predefined colors
            const Text(
              'Colori predefiniti',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: PredefinedColors.colors.length,
                itemBuilder: (context, index) {
                  final color = PredefinedColors.colors[index];
                  final isSelected = currentColor.toARGB32() == color.toARGB32();
                  
                  return InkWell(
                    onTap: () => _selectColor(color),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentGreen
                              : (color == Colors.white ? Colors.grey.shade700 : Colors.transparent),
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.accentGreen.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 2,
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
            // Close button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Conferma',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRGBSlider(
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.3),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 255,
              divisions: 255,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 35,
          child: Text(
            value.toInt().toString(),
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _selectColor(Color color) {
    if (widget.isTeam1) {
      ref.read(team1ColorProvider.notifier).state = color;
    } else {
      ref.read(team2ColorProvider.notifier).state = color;
    }
    setState(() {
      _showCustomPicker = false;
    });
  }

  void _updateCustomColor() {
    final customColor = Color.fromARGB(
      255,
      _red.toInt(),
      _green.toInt(),
      _blue.toInt(),
    );
    
    if (widget.isTeam1) {
      ref.read(team1ColorProvider.notifier).state = customColor;
    } else {
      ref.read(team2ColorProvider.notifier).state = customColor;
    }
  }
}
