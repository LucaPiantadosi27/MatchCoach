import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/scout_statistics.dart';

final aiAnalysisRepositoryProvider = Provider<AiAnalysisRepository>((ref) {
  final apiKey = (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
  return AiAnalysisRepository(apiKey: apiKey);
});

class AnalysisResult {
  final ScoutStatistics statistics;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  AnalysisResult({
    required this.statistics,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });
}

class AiAnalysisRepository {
  final String _apiKey;

  AiAnalysisRepository({required String apiKey}) : _apiKey = apiKey;

  /// Analizza la partita caricando il video e gestendo processi a blocchi (Chunking)
  /// [teamContext] contiene i nomi e i colori delle squadre per il prompt AI.
  Future<AnalysisResult> analyzeMatchVideo(
    XFile videoFile, {
    TeamContext? teamContext,
  }) async {
    final bytes = await videoFile.readAsBytes();
    return analyzeMatchVideoFromBytes(bytes, videoFile.name, teamContext: teamContext);
  }

  /// Analizza partita da bytes diretti (più affidabile su web)
  Future<AnalysisResult> analyzeMatchVideoFromBytes(
    Uint8List bytes,
    String fileName, {
    TeamContext? teamContext,
  }) async {
    if (_apiKey.isEmpty) throw Exception('API Key mancante.');

    try {
      // 1. Upload del video via Gemini File API (da bytes)
      final uploadedFileName = await _uploadVideoBytes(bytes, bytes.length);

      // 2. Attesa disponibilità file e recupero metadati (URI e Durata)
      final fileData = await _waitForFileActive(uploadedFileName);
      final fileUri = fileData['uri'] as String;
      final totalDurationSeconds = fileData['duration'] as double;
      debugPrint('Video caricato: $fileUri, Durata: ${totalDurationSeconds}s');

      // 3. Calcolo dei Chunk (es. ogni 2 minuti = 120 secondi per gestire i 3 FPS)
      const int chunkSeconds = 120;
      int numChunks;
      if (totalDurationSeconds <= 0) {
        debugPrint('⚠️ Durata video non disponibile, analisi intero video');
        numChunks = 1;
      } else {
        numChunks = (totalDurationSeconds / chunkSeconds).ceil();
        if (numChunks == 0) numChunks = 1;
      }

      List<ScoutStatistics> chunkResults = [];
      int totalPromptTokens = 0;
      int totalCompletionTokens = 0;
      int totalTokens = 0;

      // 4. Analisi Ciclica per Blocchi
      for (int i = 0; i < numChunks; i++) {
        double? startTime;
        double? endTime;
        
        if (totalDurationSeconds > 0) {
          startTime = i * chunkSeconds.toDouble();
          endTime = (i + 1) * chunkSeconds.toDouble();
          if (endTime > totalDurationSeconds) endTime = totalDurationSeconds;
          debugPrint('Analizzando blocco ${i + 1}/$numChunks (Secondi: $startTime - $endTime)');
        } else {
          debugPrint('Analizzando intero video (blocco ${i + 1}/$numChunks)');
        }
        
        final prompt = _buildAnalysisPrompt(
          startTime: startTime, 
          endTime: endTime,
          teamContext: teamContext,
        );

        // Fallback tra modelli disponibili (verificati con API)
        final fallbacks = [
          'gemini-2.5-flash',
          'gemini-2.0-flash',
          'gemini-flash-latest',
          'gemini-2.5-pro',
        ];

        Map<String, dynamic>? response;
        String? lastErr;
        for (final model in fallbacks) {
          try {
            response = await _sendRestRequest(
              'v1beta',
              model,
              prompt,
              fileUri,
            );
            if (response != null) break;
          } catch (e) {
             lastErr = e.toString();
             debugPrint('Chunk ${i+1} fallito con $model: $e');
             if (lastErr.contains('429')) {
               debugPrint('⏳ Quota esaurita per $model, attendo 20s prima del prossimo modello...');
               await Future.delayed(const Duration(seconds: 20));
             }
          }
        }

        if (response == null) throw Exception('Analisi blocco ${i+1} fallita: $lastErr');
        
        final chunkText = response['text'] as String;
        totalPromptTokens += response['promptTokens'] as int;
        totalCompletionTokens += response['completionTokens'] as int;
        totalTokens += response['totalTokens'] as int;

        final cleanedJson = _extractJson(chunkText);
        chunkResults.add(ScoutStatistics.fromJson(jsonDecode(cleanedJson)));
      }

      // 5. Unificazione dei Risultati (Merging)
      final mergedStats = _mergeAnalyses(chunkResults);
      return AnalysisResult(
        statistics: mergedStats,
        promptTokens: totalPromptTokens,
        completionTokens: totalCompletionTokens,
        totalTokens: totalTokens,
      );

    } catch (e) {
       throw Exception('Errore analisi a blocchi: $e');
    }
  }

  /// Upload Resumable tramite File API (da XFile)
  Future<String> _uploadLargeVideo(XFile videoFile) async {
    final length = await videoFile.length();
    final bytes = await videoFile.readAsBytes();
    return _uploadVideoBytes(bytes, length);
  }

  /// Upload diretto da bytes (più affidabile su web)
  Future<String> _uploadVideoBytes(Uint8List bytes, int length) async {
    const mimeType = 'video/mp4';
    final urlStart = Uri.parse('https://generativelanguage.googleapis.com/upload/v1beta/files?key=$_apiKey');

    final headers = {
      'X-Goog-Upload-Protocol': 'resumable',
      'X-Goog-Upload-Command': 'start',
      'X-Goog-Upload-Header-Content-Length': length.toString(),
      'X-Goog-Upload-Header-Content-Type': mimeType,
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "file": {"display_name": "Match ${DateTime.now().millisecondsSinceEpoch}"}
    });

    final resStart = await http.post(urlStart, headers: headers, body: body);
    if (resStart.statusCode != 200) throw Exception('Upload start failed: ${resStart.body}');

    final uploadUrlStr = resStart.headers['x-goog-upload-url'];
    if (uploadUrlStr == null) throw Exception('Upload URL mancante.');

    // Upload diretto con POST e body bytes
    final uploadRes = await http.post(
      Uri.parse(uploadUrlStr),
      headers: {
        'Content-Length': length.toString(),
        'X-Goog-Upload-Offset': '0',
        'X-Goog-Upload-Command': 'upload, finalize',
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );

    if (uploadRes.statusCode != 200) {
      throw Exception('Upload failed: ${uploadRes.statusCode} ${uploadRes.body}');
    }

    final data = jsonDecode(uploadRes.body);
    return data['file']['name'];
  }

  /// Polling dello stato del file (max 10 minuti)
  Future<Map<String, dynamic>> _waitForFileActive(String fileName) async {
    int attempts = 0;
    const maxAttempts = 120; // 120 * 5s = 10 minuti
    while (attempts < maxAttempts) {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/$fileName?key=$_apiKey');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['state'] == 'ACTIVE') {
          String? durStr = data['videoMetadata']?['duration'];
          double durSec = 0.0;
          if (durStr != null) durSec = double.tryParse(durStr.replaceAll('s', '')) ?? 0.0;
          debugPrint('File pronto dopo ${attempts * 5}s, durata: ${durSec}s');
          return {'uri': data['uri'], 'duration': durSec};
        }
        debugPrint('Attesa file Gemini... tentativo $attempts/${maxAttempts}');
        await Future.delayed(const Duration(seconds: 5));
        attempts++;
      } else {
        throw Exception('Polling error: ${res.statusCode}');
      }
    }
    throw Exception('Timeout: il video impiega troppo tempo per essere processato da Gemini');
  }

  Future<Map<String, dynamic>> _sendRestRequest(String apiVer, String model, String prompt, String fileUri) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/$apiVer/models/$model:generateContent?key=$_apiKey');
    final body = jsonEncode({
      "contents": [{
        "parts": [
          {"text": prompt},
          {"file_data": {"mime_type": "video/mp4", "file_uri": fileUri}}
        ]
      }],
      "generationConfig": {"temperature": 0.1, "maxOutputTokens": 8192}
    });

    final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
      final usage = data['usageMetadata'] ?? {};
      return {
        'text': text,
        'promptTokens': usage['promptTokenCount'] ?? 0,
        'completionTokens': usage['candidatesTokenCount'] ?? 0,
        'totalTokens': usage['totalTokenCount'] ?? 0,
      };
    }
    throw Exception('Model $model HTTP ${res.statusCode}: ${res.body}');
  }

  String _extractJson(String text) {
    final startIndex = text.indexOf('{');
    final endIndex = text.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1) return text.substring(startIndex, endIndex + 1);
    return text.replaceAll(RegExp(r'```json\n|```json|```'), '').trim();
  }

  ScoutStatistics _mergeAnalyses(List<ScoutStatistics> chunks) {
    if (chunks.isEmpty) throw Exception('Nessun dato');
    ScoutStatistics merged = chunks.first;
    int hShots = 0, aShots = 0, hRec = 0, aRec = 0;
    double hXg = 0.0, aXg = 0.0, hPoss = 0.0, aPoss = 0.0;
    
    for (var c in chunks) {
      hShots += c.homeTeam.offensivePhase.shots.total;
      aShots += c.awayTeam.offensivePhase.shots.total;
      hRec += c.homeTeam.defensivePhase.pressureAndRecovery.ballRecoveries;
      aRec += c.awayTeam.defensivePhase.pressureAndRecovery.ballRecoveries;
      hXg += c.homeTeam.advancedIndicators.teamXG;
      aXg += c.awayTeam.advancedIndicators.teamXG;
      hPoss += c.homeTeam.possessionAndBuildUp.totalPossessionPercent;
      aPoss += c.awayTeam.possessionAndBuildUp.totalPossessionPercent;
    }

    return merged.copyWith(
      homeTeam: merged.homeTeam.copyWith(
        possessionAndBuildUp: merged.homeTeam.possessionAndBuildUp.copyWith(totalPossessionPercent: (hPoss / chunks.length).round()),
        offensivePhase: merged.homeTeam.offensivePhase.copyWith(shots: merged.homeTeam.offensivePhase.shots.copyWith(total: hShots)),
        defensivePhase: merged.homeTeam.defensivePhase.copyWith(pressureAndRecovery: merged.homeTeam.defensivePhase.pressureAndRecovery.copyWith(ballRecoveries: hRec)),
        advancedIndicators: merged.homeTeam.advancedIndicators.copyWith(teamXG: hXg),
      ),
      awayTeam: merged.awayTeam.copyWith(
        possessionAndBuildUp: merged.awayTeam.possessionAndBuildUp.copyWith(totalPossessionPercent: (aPoss / chunks.length).round()),
        offensivePhase: merged.awayTeam.offensivePhase.copyWith(shots: merged.awayTeam.offensivePhase.shots.copyWith(total: aShots)),
        defensivePhase: merged.awayTeam.defensivePhase.copyWith(pressureAndRecovery: merged.awayTeam.defensivePhase.pressureAndRecovery.copyWith(ballRecoveries: aRec)),
        advancedIndicators: merged.awayTeam.advancedIndicators.copyWith(teamXG: aXg),
      ),
      reportSummary: merged.reportSummary.copyWith(
        overview: "Analisi completata su ${chunks.length} segmenti.",
        analysis: chunks.map((c) => c.reportSummary.overview).join("\n\n"),
      ),
    );
  }

  String _buildAnalysisPrompt({double? startTime, double? endTime, TeamContext? teamContext}) {
    final range = (startTime != null && endTime != null)
        ? "Analizza SOLO l'intervallo da $startTime a $endTime secondi del video."
        : "Analizza l'intero video.";

    final teamInfo = teamContext != null
        ? '''
INFORMAZIONI SQUADRE:
- Squadra di CASA: "${teamContext.homeName}" (maglia ${teamContext.homeColor})
- Squadra OSPITE: "${teamContext.awayName}" (maglia ${teamContext.awayColor})
Identifica le squadre dal colore della maglia e usa i nomi forniti.
'''
        : '';

    final homeName = teamContext?.homeName ?? 'Squadra Casa';
    final awayName = teamContext?.awayName ?? 'Squadra Ospite';

    return '''
Sei un analista tattico professionista di futsal. $range
$teamInfo
ISTRUZIONI CRITICHE:
1. GUARDA ATTENTAMENTE il video e CONTA i dati REALI
2. NON inventare dati, NON copiare valori di esempio
3. Se non vedi qualcosa chiaramente, metti 0
4. Compila TUTTI i campi del JSON basandoti SOLO su ciò che osservi

Restituisci SOLO un JSON valido con questa struttura COMPLETA per ENTRAMBE le squadre.
Sostituisci ogni valore con i DATI REALI estratti dal video:

{
  "homeTeam": {
    "teamName": "$homeName",
    "possessionAndBuildUp": {
      "totalPossessionPercent": 0,
      "possessionByZone": {"defense": 0, "midfield": 0, "attack": 0},
      "averagePossessionTimeSeconds": 0.0,
      "totalPossessions": 0,
      "averagePassesPerPossession": 0.0,
      "possessionsType": {"sterile": 0, "productive": 0},
      "passes": {
        "total": 0, "accuracyPercent": 0,
        "direction": {"forward": 0, "lateral": 0, "backward": 0},
        "betweenLines": 0, "keyPasses": 0, "underPressure": 0,
        "oneTouch": 0, "twoPlusTouches": 0, "longSequences": 0
      },
      "progression": {
        "ballCarries": 0,
        "dribbles": {"successful": 0, "failed": 0},
        "defensiveLineBreaks": 0, "finalThirdEntries": 0
      }
    },
    "offensivePhase": {
      "shots": {
        "total": 0, "onTarget": 0, "offTarget": 0, "blocked": 0,
        "xG": 0.0, "insideArea": 0, "outsideArea": 0, "fromSetPieces": 0
      },
      "creation": {
        "chancesCreated": 0, "bigChances": 0, "assists": 0,
        "preAssists": 0, "offensive1v1Won": 0, "offBallCuts": 0
      },
      "mostDangerousPlayer": {
        "name": "", "shotsGenerated": 0, "individualXG": 0.0,
        "chancesCreated": 0, "dribblesSuccessful": 0, "offensiveInvolvementPercent": 0
      }
    },
    "defensivePhase": {
      "pressureAndRecovery": {
        "ballRecoveries": 0,
        "recoveryZones": {"high": 0, "medium": 0, "low": 0},
        "pressing": {"successful": 0, "failed": 0},
        "averageRecoveryTimeSeconds": 0.0
      },
      "duels": {
        "defensiveWon": 0, "defensiveLost": 0, "successfulTackles": 0,
        "interceptions": 0, "shotsBlocked": 0, "defensive1v1": 0
      },
      "structure": {
        "defensiveLine": "", "compactness": "",
        "defensiveRotations": "", "criticalErrors": 0
      }
    },
    "transitions": {
      "offensive": {
        "counterAttacks": 0, "developmentSpeed": "",
        "outcomes": {"shots": 0, "goals": 0, "lostBalls": 0}
      },
      "defensive": {
        "recoveryTimeSeconds": 0.0, "tacticalFouls": 0, "goalsConcededInTransition": 0
      }
    },
    "spatialAnalysis": {
      "teamHeatmap": "",
      "mostUsedZones": [],
      "chanceCreationZones": [],
      "recoveryZones": [],
      "spaceOccupation": {"widthUsage": "", "depthUsage": "", "betweenLinesPlay": ""}
    },
    "teamTactics": {
      "system": {"starting": "", "changes": []},
      "possession": {"buildUp": "", "rotations": "", "pivotUsage": ""},
      "defense": {"pressing": "", "style": ""}
    },
    "setPieces": {
      "cornersTaken": 0, "cornerRoutines": 0, "freeKicks": 0,
      "accumulatedFouls": 0, "doublePenalties": 0
    },
    "decisionMaking": {
      "underPressureChoices": "", "gameTempo": "",
      "unforcedErrors": 0, "superiorityChoices": ""
    },
    "intensityAndTempo": {
      "gameSpeed": "", "actionsPerMinute": 0.0,
      "tempoChanges": "", "pressure": ""
    },
    "advancedIndicators": {
      "teamXG": 0.0, "teamXA": 0.0, "ppda": 0.0,
      "possessionsPerShot": 0.0,
      "offensiveEfficiencyPercent": 0, "defensiveEfficiencyPercent": 0
    },
    "scoutInsights": {
      "lineBreakers": [], "superiorityCreators": [],
      "gameSlowers": [], "gameAccelerators": [],
      "recurrentPatterns": [], "weaknesses": []
    }
  },
  "awayTeam": {
    "teamName": "$awayName",
    "possessionAndBuildUp": {
      "totalPossessionPercent": 0,
      "possessionByZone": {"defense": 0, "midfield": 0, "attack": 0},
      "averagePossessionTimeSeconds": 0.0,
      "totalPossessions": 0,
      "averagePassesPerPossession": 0.0,
      "possessionsType": {"sterile": 0, "productive": 0},
      "passes": {
        "total": 0, "accuracyPercent": 0,
        "direction": {"forward": 0, "lateral": 0, "backward": 0},
        "betweenLines": 0, "keyPasses": 0, "underPressure": 0,
        "oneTouch": 0, "twoPlusTouches": 0, "longSequences": 0
      },
      "progression": {
        "ballCarries": 0,
        "dribbles": {"successful": 0, "failed": 0},
        "defensiveLineBreaks": 0, "finalThirdEntries": 0
      }
    },
    "offensivePhase": {
      "shots": {
        "total": 0, "onTarget": 0, "offTarget": 0, "blocked": 0,
        "xG": 0.0, "insideArea": 0, "outsideArea": 0, "fromSetPieces": 0
      },
      "creation": {
        "chancesCreated": 0, "bigChances": 0, "assists": 0,
        "preAssists": 0, "offensive1v1Won": 0, "offBallCuts": 0
      },
      "mostDangerousPlayer": {
        "name": "", "shotsGenerated": 0, "individualXG": 0.0,
        "chancesCreated": 0, "dribblesSuccessful": 0, "offensiveInvolvementPercent": 0
      }
    },
    "defensivePhase": {
      "pressureAndRecovery": {
        "ballRecoveries": 0,
        "recoveryZones": {"high": 0, "medium": 0, "low": 0},
        "pressing": {"successful": 0, "failed": 0},
        "averageRecoveryTimeSeconds": 0.0
      },
      "duels": {
        "defensiveWon": 0, "defensiveLost": 0, "successfulTackles": 0,
        "interceptions": 0, "shotsBlocked": 0, "defensive1v1": 0
      },
      "structure": {
        "defensiveLine": "", "compactness": "",
        "defensiveRotations": "", "criticalErrors": 0
      }
    },
    "transitions": {
      "offensive": {
        "counterAttacks": 0, "developmentSpeed": "",
        "outcomes": {"shots": 0, "goals": 0, "lostBalls": 0}
      },
      "defensive": {
        "recoveryTimeSeconds": 0.0, "tacticalFouls": 0, "goalsConcededInTransition": 0
      }
    },
    "spatialAnalysis": {
      "teamHeatmap": "",
      "mostUsedZones": [],
      "chanceCreationZones": [],
      "recoveryZones": [],
      "spaceOccupation": {"widthUsage": "", "depthUsage": "", "betweenLinesPlay": ""}
    },
    "teamTactics": {
      "system": {"starting": "", "changes": []},
      "possession": {"buildUp": "", "rotations": "", "pivotUsage": ""},
      "defense": {"pressing": "", "style": ""}
    },
    "setPieces": {
      "cornersTaken": 0, "cornerRoutines": 0, "freeKicks": 0,
      "accumulatedFouls": 0, "doublePenalties": 0
    },
    "decisionMaking": {
      "underPressureChoices": "", "gameTempo": "",
      "unforcedErrors": 0, "superiorityChoices": ""
    },
    "intensityAndTempo": {
      "gameSpeed": "", "actionsPerMinute": 0.0,
      "tempoChanges": "", "pressure": ""
    },
    "advancedIndicators": {
      "teamXG": 0.0, "teamXA": 0.0, "ppda": 0.0,
      "possessionsPerShot": 0.0,
      "offensiveEfficiencyPercent": 0, "defensiveEfficiencyPercent": 0
    },
    "scoutInsights": {
      "lineBreakers": [], "superiorityCreators": [],
      "gameSlowers": [], "gameAccelerators": [],
      "recurrentPatterns": [], "weaknesses": []
    }
  },
  "reportSummary": {
    "overview": "[Sintesi di ciò che hai osservato]",
    "analysis": "[Analisi tattica dettagliata]",
    "strengthsAndWeaknesses": "[Punti di forza e debolezza osservati]",
    "conclusions": "[Conclusioni e suggerimenti]"
  }
}

RICORDA: Sostituisci OGNI valore 0 con i DATI REALI contati dal video!
Non lasciare tutto a 0 - analizza ATTENTAMENTE il video!
''';
  }
}

/// Contesto squadre da passare al prompt AI
class TeamContext {
  final String homeName;
  final String homeColor;
  final String awayName;
  final String awayColor;

  const TeamContext({
    required this.homeName,
    required this.homeColor,
    required this.awayName,
    required this.awayColor,
  });
}
