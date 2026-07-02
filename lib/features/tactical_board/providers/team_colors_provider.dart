import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider per il colore della Squadra 1 (Team A)
final team1ColorProvider = StateProvider<Color>((ref) => Colors.red);

// Provider per il colore della Squadra 2 (Team B)
final team2ColorProvider = StateProvider<Color>((ref) => Colors.blue);

// Colori predefiniti disponibili
class PredefinedColors {
  static const List<Color> colors = [
    // Rossi
    Color(0xFFE53935), // Rosso
    Color(0xFFD32F2F), // Rosso scuro
    Color(0xFFFF5252), // Rosso chiaro
    Color(0xFFFF1744), // Rosso acceso
    
    // Blu
    Color(0xFF1E88E5), // Blu
    Color(0xFF1565C0), // Blu scuro
    Color(0xFF42A5F5), // Blu chiaro
    Color(0xFF2196F3), // Blu medio
    
    // Verdi
    Color(0xFF43A047), // Verde
    Color(0xFF2E7D32), // Verde scuro
    Color(0xFF66BB6A), // Verde chiaro
    Color(0xFF00C853), // Verde acceso
    
    // Gialli/Arancioni
    Color(0xFFFDD835), // Giallo
    Color(0xFFFBC02D), // Giallo scuro
    Color(0xFFFFEB3B), // Giallo chiaro
    Color(0xFFFF6F00), // Arancione
    Color(0xFFFF9800), // Arancione chiaro
    
    // Viola/Rosa
    Color(0xFF8E24AA), // Viola
    Color(0xFF6A1B9A), // Viola scuro
    Color(0xFFAB47BC), // Viola chiaro
    Color(0xFFE91E63), // Rosa
    Color(0xFFC2185B), // Rosa scuro
    
    // Marroni
    Color(0xFF6D4C41), // Marrone
    Color(0xFF5D4037), // Marrone scuro
    Color(0xFF8D6E63), // Marrone chiaro
    
    // Grigi
    Color(0xFF757575), // Grigio
    Color(0xFF424242), // Grigio scuro
    Color(0xFF9E9E9E), // Grigio chiaro
    
    // Bianco/Nero
    Color(0xFFFFFFFF), // Bianco
    Color(0xFF000000), // Nero
    
    // Turchesi/Cyan
    Color(0xFF00ACC1), // Turchese
    Color(0xFF00838F), // Turchese scuro
    Color(0xFF26C6DA), // Cyan
    
    // Altri
    Color(0xFF5E35B1), // Indaco
    Color(0xFFFF5722), // Rosso-arancio
    Color(0xFF795548), // Marrone terra
  ];
  
  static String getColorName(Color color) {
    if (color.toARGB32() == 0xFFE53935) return 'Rosso';
    if (color.toARGB32() == 0xFFD32F2F) return 'Rosso scuro';
    if (color.toARGB32() == 0xFFFF5252) return 'Rosso chiaro';
    if (color.toARGB32() == 0xFFFF1744) return 'Rosso acceso';
    
    if (color.toARGB32() == 0xFF1E88E5) return 'Blu';
    if (color.toARGB32() == 0xFF1565C0) return 'Blu scuro';
    if (color.toARGB32() == 0xFF42A5F5) return 'Blu chiaro';
    if (color.toARGB32() == 0xFF2196F3) return 'Blu medio';
    
    if (color.toARGB32() == 0xFF43A047) return 'Verde';
    if (color.toARGB32() == 0xFF2E7D32) return 'Verde scuro';
    if (color.toARGB32() == 0xFF66BB6A) return 'Verde chiaro';
    if (color.toARGB32() == 0xFF00C853) return 'Verde acceso';
    
    if (color.toARGB32() == 0xFFFDD835) return 'Giallo';
    if (color.toARGB32() == 0xFFFBC02D) return 'Giallo scuro';
    if (color.toARGB32() == 0xFFFFEB3B) return 'Giallo chiaro';
    if (color.toARGB32() == 0xFFFF6F00) return 'Arancione';
    if (color.toARGB32() == 0xFFFF9800) return 'Arancione chiaro';
    
    if (color.toARGB32() == 0xFF8E24AA) return 'Viola';
    if (color.toARGB32() == 0xFF6A1B9A) return 'Viola scuro';
    if (color.toARGB32() == 0xFFAB47BC) return 'Viola chiaro';
    if (color.toARGB32() == 0xFFE91E63) return 'Rosa';
    if (color.toARGB32() == 0xFFC2185B) return 'Rosa scuro';
    
    if (color.toARGB32() == 0xFF6D4C41) return 'Marrone';
    if (color.toARGB32() == 0xFF5D4037) return 'Marrone scuro';
    if (color.toARGB32() == 0xFF8D6E63) return 'Marrone chiaro';
    
    if (color.toARGB32() == 0xFF757575) return 'Grigio';
    if (color.toARGB32() == 0xFF424242) return 'Grigio scuro';
    if (color.toARGB32() == 0xFF9E9E9E) return 'Grigio chiaro';
    
    if (color.toARGB32() == 0xFFFFFFFF) return 'Bianco';
    if (color.toARGB32() == 0xFF000000) return 'Nero';
    
    if (color.toARGB32() == 0xFF00ACC1) return 'Turchese';
    if (color.toARGB32() == 0xFF00838F) return 'Turchese scuro';
    if (color.toARGB32() == 0xFF26C6DA) return 'Cyan';
    
    if (color.toARGB32() == 0xFF5E35B1) return 'Indaco';
    if (color.toARGB32() == 0xFFFF5722) return 'Rosso-arancio';
    if (color.toARGB32() == 0xFF795548) return 'Marrone terra';
    
    return 'Personalizzato';
  }
}
