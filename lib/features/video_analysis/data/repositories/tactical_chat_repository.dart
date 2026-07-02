import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lavagna_tattica/core/supabase_client.dart';
import '../models/scout_statistics.dart';
import '../models/chat_message.dart';

final tacticalChatRepositoryProvider = Provider<TacticalChatRepository>((ref) {
  final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  return TacticalChatRepository(apiKey: apiKey); 
});

class TacticalChatRepository {
  final String _apiKey;
  final List<ChatMessage> _history = [];
  ScoutStatistics? _analysisContext;
  String? _currentAnalysisId;

  TacticalChatRepository({required String apiKey}) : _apiKey = apiKey;

  void setContext(ScoutStatistics analysis, {String? analysisId}) {
    _analysisContext = analysis;
    _currentAnalysisId = analysisId;
    _history.clear();
  }

  List<ChatMessage> get history => List.unmodifiable(_history);

  /// Carica la cronologia messaggi da Supabase
  Future<void> loadPersistentHistory(String analysisId) async {
    try {
      final response = await supabase
          .from('chat_messages')
          .select()
          .eq('analysis_id', analysisId)
          .order('created_at', ascending: true);

      _history.clear();
      for (final row in response) {
        _history.add(ChatMessage(
          role: row['role'] == 'user' ? ChatRole.user : ChatRole.model,
          text: row['text'],
          timestamp: DateTime.parse(row['created_at']),
        ));
      }
    } catch (e) {
      debugPrint('Errore caricamento history: $e');
    }
  }

  /// Salva un singolo messaggio su Supabase
  Future<void> _saveMessageToSupabase(ChatMessage msg) async {
    if (_currentAnalysisId == null) return;
    try {
      await supabase.from('chat_messages').insert({
        'analysis_id': _currentAnalysisId,
        'role': msg.role.name,
        'text': msg.text,
      });
    } catch (e) {
      debugPrint('Errore salvataggio messaggio: $e');
    }
  }

  Future<String> sendMessage(String userMessage) async {
    if (_analysisContext == null) {
      throw Exception('Contesto analisi non impostato');
    }

    final userMsg = ChatMessage(role: ChatRole.user, text: userMessage);
    _history.add(userMsg);
    await _saveMessageToSupabase(userMsg);

    // Strategia di fallback per la chat (simile all'analisi)
    final chatFallbacks = [
      'gemini-flash-lite-latest',
      'gemini-2.0-flash-lite',
      'gemini-flash-latest',
      'gemini-2.0-flash',
    ];

    String? lastResponse;
    String? lastErr;

    for (final model in chatFallbacks) {
      try {
        final prompt = _buildChatPromptWithHistory(userMessage);
        lastResponse = await _sendRestRequest(model, prompt);
        
        if (lastResponse.isNotEmpty) {
          final modelMsg = ChatMessage(role: ChatRole.model, text: lastResponse);
          _history.add(modelMsg);
          await _saveMessageToSupabase(modelMsg);
          return lastResponse;
        }
      } catch (e) {
        lastErr = e.toString();
        debugPrint('Tentativo chat con $model fallito: $e');
        if (lastErr.contains('429') || lastErr.contains('503')) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }

    throw Exception('La chat ha fallito tutti i tentativi di risposta. Ultimo errore: $lastErr');
  }

  String _buildChatPromptWithHistory(String query) {
    final contextJson = jsonEncode(_analysisContext!.toJson());
    
    // Costruiamo la cronologia testuale
    String historyText = "";
    if (_history.length > 1) {
      final historyEntries = _history.take(_history.length - 1).map((m) => "${m.role == ChatRole.user ? 'UTENTE' : 'COACH'}: ${m.text}").join("\n");
      historyText = "\nCronologia conversazione precedente:\n$historyEntries";
    }

    return '''
      Tu sei un Match Coach esperto di Calcio a 5 (Futsal).
      Hai a disposizione l'analisi tecnica di una partita in formato JSON:
      
      $contextJson
      
      $historyText
      
      Rispondi alla seguente domanda basandoti sui dati della partita e considerando il contesto della conversazione passata.
      Sii tecnico, preciso e motivante. Proponi soluzioni tattiche se richieste.
      
      Domanda attuale: $query
    ''';
  }

  Future<String> _sendRestRequest(String model, String prompt) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey');
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [{"text": prompt}]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topP": 0.95,
          "maxOutputTokens": 1000
        }
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
}
