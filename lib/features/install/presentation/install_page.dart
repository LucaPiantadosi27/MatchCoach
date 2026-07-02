import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavagna_tattica/core/theme.dart';

class InstallPage extends ConsumerWidget {
  const InstallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Installa MatchCoach'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A3020), Color(0xFF0D1117)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.sidebarBorderColor),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.download_rounded,
                    size: 64,
                    color: AppTheme.accentGreen,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Installa MatchCoach sul tuo dispositivo',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Accedi rapidamente all\'app direttamente dalla home del tuo telefono',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Android instructions
            _buildPlatformSection(
              context,
              icon: Icons.android,
              iconColor: const Color(0xFF3DDC84),
              title: 'Android (Chrome)',
              steps: [
                'Apri questo sito con Chrome sul tuo telefono Android',
                'Tocca il menu (⋮) in alto a destra',
                'Seleziona "Installa app" o "Aggiungi a schermata Home"',
                'Conferma l\'installazione toccando "Installa"',
                'L\'icona apparirà nella schermata Home',
              ],
            ),
            const SizedBox(height: 24),

            // iOS instructions
            _buildPlatformSection(
              context,
              icon: Icons.apple,
              iconColor: const Color(0xFFFFFFFF),
              title: 'iOS / iPhone (Safari)',
              steps: [
                'Apri questo sito con Safari sul tuo iPhone',
                'Tocca il pulsante Condividi (□↑) in basso',
                'Scorri e seleziona "Aggiungi a Home"',
                'Modifica il nome se vuoi, poi tocca "Aggiungi"',
                'L\'app apparirà nella schermata Home come un\'app nativa',
              ],
            ),
            const SizedBox(height: 24),

            // Desktop instructions
            _buildPlatformSection(
              context,
              icon: Icons.computer,
              iconColor: const Color(0xFF4285F4),
              title: 'Desktop (Chrome/Edge)',
              steps: [
                'Apri questo sito con Chrome o Edge',
                'Cerca l\'icona di installazione (⊕) nella barra degli indirizzi',
                'Clicca su "Installa MatchCoach"',
                'L\'app si aprirà in una finestra dedicata',
              ],
            ),
            const SizedBox(height: 32),

            // Benefits section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.sidebarBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Vantaggi dell\'installazione',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildBenefitRow('Accesso rapido dalla schermata Home'),
                  _buildBenefitRow('Funziona offline dopo il primo caricamento'),
                  _buildBenefitRow('Esperienza a schermo intero senza browser'),
                  _buildBenefitRow('Notifiche push (in arrivo)'),
                  _buildBenefitRow('Prestazioni migliorate'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Help section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade700.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Non vedi l\'opzione di installazione? Assicurati di usare un browser compatibile (Chrome, Safari, Edge).',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[200],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // CTA button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_rounded),
                label: const Text(
                  'Torna alla Home',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformSection(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.sidebarBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentGreen, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppTheme.accentGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
