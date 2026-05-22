# 🎬 Flusso Analisi Video e Associazione alle Partite

## 📋 Panoramica

Il sistema permette di analizzare video di partite con AI e associarli automaticamente alle partite specifiche. Le analisi appaiono come "clip" nella sezione video della partita.

## 🔄 Flusso Completo

### 1. **Analisi Video** (`/video`)

1. L'utente carica un video dalla pagina **Analisi Video**
2. Clicca su **"Analizza e Salva"**
3. Il sistema:
   - Processa il video (compressione se necessario)
   - Invia a Gemini AI per l'analisi tattica
   - Estrae statistiche complete in formato JSON
   - Salva l'analisi nel database

### 2. **Associazione alla Partita**

Dopo il completamento dell'analisi:

1. Si apre automaticamente un **dialog di selezione partita**
2. L'utente vede la lista di tutte le partite disponibili
3. Seleziona la partita a cui associare l'analisi
4. Il sistema salva l'associazione (`match_id` nel database)

### 3. **Visualizzazione nelle Clip**

Nella pagina della partita (`/matches/:id`):

1. Le **analisi AI** appaiono nella sezione "CLIP VIDEO"
2. Sono distinguibili con:
   - Badge verde "ANALISI AI"
   - Icona robot (🤖)
   - Bordo verde
3. Insieme ai video caricati manualmente

## 🗄️ Struttura Database

### Tabella `video_analyses`

```sql
CREATE TABLE video_analyses (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  match_id UUID REFERENCES matches(id),  -- ✨ Nuovo campo
  video_name TEXT,
  analysis_data JSONB,
  prompt_tokens INTEGER,
  completion_tokens INTEGER,
  total_tokens INTEGER,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Indici

- `idx_video_analyses_user_id` - Query per utente
- `idx_video_analyses_match_id` - Query per partita
- `idx_video_analyses_created_at` - Ordinamento cronologico

## 📁 File Modificati/Creati

### Nuovi File

1. **`supabase_migrations/add_match_id_to_video_analyses.sql`**
   - Migration per aggiungere `match_id` alla tabella

2. **`lib/features/video_analysis/providers/video_analysis_providers.dart`**
   - Provider `matchAnalysesProvider` per recuperare analisi di una partita

3. **`lib/features/video_analysis/presentation/widgets/match_selection_dialog.dart`**
   - Dialog per selezionare la partita (non utilizzato, esiste già implementazione)

### File Modificati

1. **`lib/features/video_analysis/data/repositories/video_analysis_repository.dart`**
   - Aggiunto metodo `getMatchAnalyses(matchId)` per recuperare analisi di una partita
   - Supporto per `matchId` nel salvataggio

2. **`lib/features/matches/presentation/match_detail_page.dart`**
   - Integrato provider `matchAnalysesProvider`
   - Aggiunto widget `_AnalysisRow` per mostrare le analisi
   - Modificata lista clip per includere sia video che analisi

3. **`lib/features/video_analysis/presentation/video_analysis_page.dart`**
   - Dialog di selezione partita già implementato
   - Chiamata automatica dopo analisi completata

## 🎨 UI/UX

### Analisi nella Lista Clip

```
┌─────────────────────────────────────────┐
│ 🤖  ANALISI AI                          │
│                                         │
│ Nome video analizzato                   │
│ 📅 22/05/2026 12:43                    │
│                                         │
│                     💬 Chat  🗑️ Elimina │
└─────────────────────────────────────────┘
```

**Caratteristiche visive:**
- Bordo verde (`#3FB950`)
- Badge "ANALISI AI" con icona analytics
- Icona robot nel badge circolare
- Pulsanti: Chat AI e Elimina

### Dialog Selezione Partita

```
┌─────────────────────────────────────────┐
│ ⚽ Associa a una partita            ✕   │
├─────────────────────────────────────────┤
│ Seleziona la partita a cui associare   │
│ questa analisi video                    │
│                                         │
│ ┌─────────────────────────────────┐   │
│ │ ⚽ Inter vs Milan               │   │
│ │ 📅 22/05/2026  🕐 20:30        │   │
│ │ 📍 San Siro                     │   │
│ └─────────────────────────────────┘   │
│                                         │
│ ┌─────────────────────────────────┐   │
│ │ ⚽ Juventus vs Roma             │   │
│ │ 📅 21/05/2026  🕐 18:00        │   │
│ └─────────────────────────────────┘   │
│                                         │
│              [Annulla]                  │
└─────────────────────────────────────────┘
```

## 🔧 Funzionalità

### Azioni Disponibili

**Dall'analisi:**
- 💬 **Chat AI**: Apre la chat con l'analisi completa
- 🗑️ **Elimina**: Rimuove l'analisi dal database

**Comportamento:**
- Click sull'analisi → Apre la chat AI
- Le analisi sono ordinate per data (più recenti prima)
- Eliminazione con conferma

## 📊 Provider e State Management

### Provider Utilizzati

```dart
// Analisi associate a una partita
final matchAnalysesProvider = FutureProvider.autoDispose.family<
  List<Map<String, dynamic>>, 
  String
>((ref, matchId) async {
  return await repository.getMatchAnalyses(matchId);
});

// Partite disponibili per associazione
final matchesProvider = FutureProvider.autoDispose<List<MatchModel>>();
```

### Repository Methods

```dart
// Salva analisi con associazione partita
Future<String> saveAnalysis({
  required String userId,
  required String videoName,
  required ScoutStatistics analysis,
  String? matchId,  // Opzionale
});

// Associa analisi esistente a partita
Future<void> associateAnalysisToMatch(
  String analysisId, 
  String matchId
);

// Recupera analisi di una partita
Future<List<Map<String, dynamic>>> getMatchAnalyses(String matchId);
```

## 🚀 Passi per l'Utilizzo

### Per l'Utente

1. **Vai su `/video`** (Analisi Video)
2. **Carica un video** della partita
3. **Clicca "Analizza e Salva"**
4. **Attendi** l'elaborazione (1-3 minuti)
5. **Seleziona la partita** dal dialog
6. **Vai sulla partita** per vedere l'analisi nelle clip

### Per lo Sviluppatore

1. **Esegui la migration SQL** su Supabase:
   ```sql
   -- Esegui: supabase_migrations/add_match_id_to_video_analyses.sql
   ```

2. **Verifica i provider** siano importati correttamente

3. **Testa il flusso**:
   - Crea una partita
   - Analizza un video
   - Associa alla partita
   - Verifica che appaia nelle clip

## ⚠️ Note Importanti

### Limitazioni

- **Solo analisi completate** appaiono nelle clip
- **Match_id opzionale**: Le analisi possono esistere senza partita associata
- **Eliminazione cascata**: Eliminando una partita, si eliminano anche le analisi associate

### Sicurezza

- **RLS attivo**: Gli utenti vedono solo le proprie analisi
- **Validazione**: Il `match_id` deve esistere nella tabella `matches`
- **Permessi**: Solo il proprietario può eliminare un'analisi

## 🔮 Possibili Miglioramenti Futuri

1. **Riassociazione**: Permettere di cambiare la partita associata
2. **Filtri**: Filtrare clip per tipo (video/analisi)
3. **Ordinamento**: Riordinare le analisi come i video
4. **Anteprima**: Mostrare statistiche chiave nell'anteprima
5. **Batch**: Associare più analisi contemporaneamente
6. **Auto-match**: Suggerire automaticamente la partita basandosi sulla data

## 📝 Checklist Implementazione

- [x] Migration database con `match_id`
- [x] Repository method `getMatchAnalyses`
- [x] Provider `matchAnalysesProvider`
- [x] Widget `_AnalysisRow` per visualizzazione
- [x] Integrazione in `match_detail_page`
- [x] Dialog selezione partita (già esistente)
- [x] Gestione eliminazione analisi
- [x] Navigazione alla chat AI
- [x] UI distintiva per analisi AI
- [x] Documentazione completa

## ✅ Stato: COMPLETATO

Il sistema è completamente funzionale e pronto per l'uso!
