import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavagna_tattica/features/tactical_board/data/models/field_background.dart';
import 'package:lavagna_tattica/features/tactical_board/providers/board_provider.dart';

class BackgroundSelector extends ConsumerWidget {
  const BackgroundSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBackground = ref.watch(fieldBackgroundProvider);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sfondo Campo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildBackgroundOption(
            context,
            ref,
            FieldBackground.green,
            currentBackground,
          ),
          const SizedBox(height: 4),
          _buildBackgroundOption(
            context,
            ref,
            FieldBackground.blue,
            currentBackground,
          ),
          const SizedBox(height: 4),
          _buildBackgroundOption(
            context,
            ref,
            FieldBackground.parquetLight,
            currentBackground,
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOption(
    BuildContext context,
    WidgetRef ref,
    FieldBackground background,
    FieldBackground currentBackground,
  ) {
    final isSelected = currentBackground.type == background.type;

    return InkWell(
      onTap: () {
        ref.read(fieldBackgroundProvider.notifier).state = background;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? background.previewColor.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? background.previewColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: background.previewColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Icon(
                background.icon,
                size: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                background.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Colors.green,
              ),
          ],
        ),
      ),
    );
  }
}
