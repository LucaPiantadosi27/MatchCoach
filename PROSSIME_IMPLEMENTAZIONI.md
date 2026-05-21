# 🚀 Prossime Implementazioni - Pipeline Analisi Video Avanzata

## 📋 Obiettivo Generale
Creare una pipeline di analisi video multi-modello per ottimizzare costi e precisione, scomponendo il processo in step specializzati con modelli dedicati per ogni task.

---

## 🎯 Architettura Proposta

### Pipeline Multi-Stage
```
Video Input → Estrazione Fotogrammi → Rilevamento Giocatori → Tracking & Identificazione → 
Analisi Tattica → Generazione JSON Strutturato → Storage & Query
```

---

## 📊 Step di Implementazione

### **FASE 1: Estrazione e Pre-processing Video**

#### Step 1.1: Estrazione Fotogrammi
**Obiettivo**: Scomporre il video in fotogrammi a intervalli regolari

**Tecnologie Suggerite**:
- **FFmpeg** (locale/server-side) - Gratuito, veloce
- **OpenCV** (Python) - Flessibile per pre-processing
- **Cloud Video Intelligence API** (Google) - Se serve OCR/scene detection

**Implementazione**:
```
- Creare servizio backend (Python/Node.js) per processing video
- Estrarre 1 frame ogni N secondi (es: 1 fps per analisi tattica)
- Salvare frames in formato compresso (JPEG/WebP)
- Generare metadata temporali per ogni frame
```

**Output**: Array di immagini con timestamp
**Costo**: ~$0 (FFmpeg locale) o ~$0.10/min (Cloud API)

---

#### Step 1.2: Pre-processing Immagini
**Obiettivo**: Normalizzare e ottimizzare le immagini per l'analisi

**Tasks**:
- Ridimensionamento uniforme (es: 1280x720)
- Correzione prospettiva campo (se necessario)
- Miglioramento contrasto/luminosità
- Rimozione watermark/overlay

**Tecnologie**: OpenCV, Pillow
**Costo**: ~$0 (processing locale)

---

### **FASE 2: Rilevamento e Tracking Giocatori**

#### Step 2.1: Object Detection - Rilevamento Giocatori
**Obiettivo**: Identificare posizione di tutti i giocatori in ogni frame

**Modelli Suggeriti** (in ordine di preferenza costo/performance):

1. **YOLOv8/YOLOv9** (Ultralytics) ⭐ **CONSIGLIATO**
   - **Pro**: Veloce, accurato, gratuito, può girare su GPU locale
   - **Costo**: $0 (self-hosted) o ~$0.001/frame (cloud)
   - **Accuratezza**: 95%+ per detection persone
   - **Implementazione**: Fine-tuning su dataset calcio

2. **Roboflow** (con modelli pre-trained per sport)
   - **Pro**: API pronta, modelli specifici per calcio
   - **Costo**: ~$0.002-0.005/frame
   - **Accuratezza**: 90-95%

3. **MediaPipe** (Google) - Gratuito
   - **Pro**: Gratis, buono per pose detection
   - **Contro**: Meno accurato per tracking multiplo
   - **Costo**: $0

**Output per ogni frame**:
```json
{
  "frame_id": "001",
  "timestamp": 1.5,
  "detections": [
    {
      "bbox": [x, y, width, height],
      "confidence": 0.95,
      "class": "player",
      "team": null  // da determinare in step successivo
    }
  ]
}
```

---

#### Step 2.2: Team Classification - Riconoscimento Squadra
**Obiettivo**: Classificare ogni giocatore per squadra in base al colore maglia

**Modelli Suggeriti**:

1. **K-Means Clustering** (OpenCV) ⭐ **CONSIGLIATO per MVP**
   - **Pro**: Veloce, gratuito, efficace per colori distinti
   - **Costo**: $0
   - **Implementazione**: Clustering colori dominanti nella bbox

2. **Custom CNN Classifier** (TensorFlow/PyTorch)
   - **Pro**: Più robusto, gestisce pattern complessi
   - **Costo**: $0 (self-hosted)
   - **Training**: Dataset di ~1000 immagini per squadra

3. **GPT-4 Vision** (solo per casi ambigui)
   - **Pro**: Altissima accuratezza
   - **Costo**: ~$0.01/frame (ALTO - usare solo se necessario)

**Output aggiornato**:
```json
{
  "bbox": [x, y, width, height],
  "confidence": 0.95,
  "team": "home",  // "home", "away", "referee"
  "team_confidence": 0.88
}
```

---

#### Step 2.3: Player Tracking - Tracciamento Identità
**Obiettivo**: Mantenere identità giocatore tra frame consecutivi

**Modelli Suggeriti**:

1. **DeepSORT** ⭐ **CONSIGLIATO**
   - **Pro**: Standard per tracking multi-object, gratuito
   - **Costo**: $0
   - **Accuratezza**: 85-90% per tracking continuo

2. **ByteTrack**
   - **Pro**: Più recente, migliore performance
   - **Costo**: $0
   - **Accuratezza**: 90-95%

3. **Supervision** (Roboflow) - Libreria Python
   - **Pro**: Facile integrazione con YOLO
   - **Costo**: $0

**Output aggiornato**:
```json
{
  "player_id": "P_001",  // ID persistente nel video
  "bbox": [x, y, width, height],
  "team": "home",
  "jersey_number": null  // opzionale, da OCR
}
```

---

#### Step 2.4: Jersey Number Recognition (Opzionale)
**Obiettivo**: Riconoscere numero maglia per identificazione precisa

**Modelli Suggeriti**:

1. **EasyOCR** ⭐ **CONSIGLIATO**
   - **Pro**: Gratuito, supporta numeri
   - **Costo**: $0
   - **Accuratezza**: 70-80% (dipende da risoluzione)

2. **PaddleOCR**
   - **Pro**: Più veloce di EasyOCR
   - **Costo**: $0

3. **Google Cloud Vision OCR** (fallback)
   - **Pro**: Altissima accuratezza
   - **Costo**: ~$1.50/1000 immagini

**Strategia**: Eseguire OCR solo su frame stabili (giocatore fermo/inquadrato bene)

---

### **FASE 3: Estrazione Coordinate e Normalizzazione**

#### Step 3.1: Coordinate Mapping
**Obiettivo**: Convertire coordinate pixel in coordinate campo reali

**Implementazione**:
- Rilevamento linee campo (Hough Transform - OpenCV)
- Calcolo matrice di omografia (prospettiva → top-down)
- Mappatura coordinate (x,y) pixel → (x,y) metri campo

**Tecnologie**: OpenCV, NumPy
**Costo**: $0

**Output**:
```json
{
  "player_id": "P_001",
  "timestamp": 1.5,
  "position": {
    "pixel": [640, 480],
    "field": [25.5, 15.2]  // metri dal centro campo
  },
  "team": "home"
}
```

---

#### Step 3.2: Change Detection - Rilevamento Sostituzioni
**Obiettivo**: Identificare quando un giocatore esce/entra dal campo

**Logica**:
- Tracking continuità player_id
- Se player_id scompare per >30 secondi → sostituzione
- Nuovo player_id appare → nuovo giocatore entrato

**Output**:
```json
{
  "event": "substitution",
  "timestamp": 45.2,
  "team": "home",
  "player_out": "P_003",
  "player_in": "P_012"
}
```

---

### **FASE 4: Analisi Tattica Avanzata**

#### Step 4.1: Calcolo Metriche Base
**Obiettivo**: Calcolare statistiche da coordinate (velocità, distanze, heatmap)

**Metriche Calcolabili**:
- Distanza percorsa per giocatore
- Velocità media/massima
- Heatmap posizionale
- Formazione tattica (clustering posizioni)
- Ampiezza/profondità squadra
- Pressing intensity (distanza da avversario con palla)

**Tecnologie**: Python (NumPy, SciPy, scikit-learn)
**Costo**: $0

---

#### Step 4.2: Event Detection - Rilevamento Eventi
**Obiettivo**: Identificare eventi chiave (passaggi, tiri, tackle)

**Approccio Ibrido**:

1. **Rule-based** (per eventi semplici) ⭐ **CONSIGLIATO per MVP**
   - Cambio possesso: distanza palla < 2m da giocatore
   - Passaggio: palla si muove da giocatore A a B (stesso team)
   - Tiro: palla verso porta con velocità > soglia
   - **Costo**: $0

2. **Action Recognition Model** (per eventi complessi)
   - **SlowFast** (Facebook AI)
   - **X3D** (Facebook AI)
   - **Costo**: $0 (self-hosted)
   - **Uso**: Solo per eventi ambigui o analisi dettagliata

---

#### Step 4.3: Analisi Tattica Contestuale con LLM
**Obiettivo**: Generare insights tattici da dati strutturati

**Modelli Suggeriti** (in ordine di costo):

1. **Gemini 1.5 Flash** ⭐ **CONSIGLIATO per analisi standard**
   - **Input**: JSON strutturato + prompt tattico
   - **Costo**: ~$0.075/1M token input, ~$0.30/1M token output
   - **Uso**: Analisi tattica generale, pattern recognition

2. **Claude 3.5 Haiku** (Anthropic)
   - **Pro**: Veloce, economico, buono per analisi
   - **Costo**: ~$0.25/1M token input, ~$1.25/1M token output
   - **Uso**: Alternativa a Gemini Flash

3. **GPT-4o mini** (OpenAI)
   - **Pro**: Economico, veloce
   - **Costo**: ~$0.15/1M token input, ~$0.60/1M token output
   - **Uso**: Analisi rapide

4. **Gemini 1.5 Pro** (attuale)
   - **Uso**: Solo per analisi molto dettagliate o multi-video
   - **Costo**: ~$1.25/1M token input, ~$5.00/1M token output

**Strategia di Ottimizzazione**:
- Usare **Gemini Flash** per 90% delle analisi
- Usare **Gemini Pro** solo per:
  - Analisi comparative multi-partita
  - Report dettagliati per scouting
  - Analisi con richieste utente complesse

---

### **FASE 5: Generazione JSON Strutturato Esteso**

#### Step 5.1: Estensione Schema JSON
**Obiettivo**: Aggiungere dati strutturati al JSON esistente

**Nuovi Campi da Aggiungere**:

```json
{
  "homeTeam": {
    "teamName": "...",
    
    // NUOVO: Dati tracking
    "trackingData": {
      "players": [
        {
          "playerId": "P_001",
          "jerseyNumber": 10,
          "positions": [
            {"timestamp": 0.0, "x": 25.5, "y": 15.2},
            {"timestamp": 0.5, "x": 26.1, "y": 15.8}
          ],
          "metrics": {
            "distanceCovered": 8500,  // metri
            "averageSpeed": 6.2,      // km/h
            "maxSpeed": 24.5,
            "sprintCount": 12,
            "heatmapZones": {
              "defense": 15,
              "midfield": 60,
              "attack": 25
            }
          }
        }
      ],
      "formations": [
        {
          "timestamp": 0.0,
          "formation": "4-3-3",
          "confidence": 0.92
        }
      ],
      "teamMetrics": {
        "averageWidth": 45.2,      // metri
        "averageDepth": 38.5,
        "compactnessIndex": 0.78,
        "pressingIntensity": 0.65
      }
    },
    
    // NUOVO: Eventi rilevati
    "events": [
      {
        "type": "pass",
        "timestamp": 12.5,
        "from": "P_001",
        "to": "P_005",
        "success": true,
        "distance": 15.2,
        "direction": "forward",
        "underPressure": false
      },
      {
        "type": "shot",
        "timestamp": 45.8,
        "player": "P_009",
        "position": {"x": 88.5, "y": 34.2},
        "outcome": "on_target",
        "xG": 0.35
      }
    ],
    
    // Campi esistenti...
    "possessionAndBuildUp": { ... },
    "offensivePhase": { ... }
  },
  
  // NUOVO: Metadata analisi
  "analysisMetadata": {
    "videoId": "...",
    "duration": 90.0,
    "framesAnalyzed": 5400,
    "modelsUsed": {
      "detection": "YOLOv8",
      "tracking": "DeepSORT",
      "analysis": "Gemini-1.5-Flash"
    },
    "processingTime": 45.2,
    "costs": {
      "detection": 0.05,
      "llm": 0.12,
      "total": 0.17
    }
  }
}
```

---

#### Step 5.2: Database Schema per Query Strutturate
**Obiettivo**: Permettere query SQL su dati analisi

**Nuove Tabelle**:

```sql
-- Tracking giocatori
CREATE TABLE player_tracking (
  id UUID PRIMARY KEY,
  analysis_id UUID REFERENCES video_analyses(id),
  player_id VARCHAR(50),
  team VARCHAR(10),
  jersey_number INT,
  timestamp FLOAT,
  position_x FLOAT,
  position_y FLOAT,
  speed FLOAT,
  created_at TIMESTAMP
);

-- Eventi partita
CREATE TABLE match_events (
  id UUID PRIMARY KEY,
  analysis_id UUID REFERENCES video_analyses(id),
  event_type VARCHAR(50),
  timestamp FLOAT,
  player_id VARCHAR(50),
  team VARCHAR(10),
  success BOOLEAN,
  metadata JSONB,
  created_at TIMESTAMP
);

-- Metriche giocatore
CREATE TABLE player_metrics (
  id UUID PRIMARY KEY,
  analysis_id UUID REFERENCES video_analyses(id),
  player_id VARCHAR(50),
  distance_covered FLOAT,
  average_speed FLOAT,
  max_speed FLOAT,
  sprint_count INT,
  heatmap_data JSONB,
  created_at TIMESTAMP
);

-- Indici per query veloci
CREATE INDEX idx_tracking_analysis ON player_tracking(analysis_id);
CREATE INDEX idx_tracking_player ON player_tracking(player_id);
CREATE INDEX idx_events_analysis ON match_events(analysis_id);
CREATE INDEX idx_events_type ON match_events(event_type);
```

---

### **FASE 6: API e Query Avanzate**

#### Step 6.1: API Endpoints per Dati Strutturati
**Obiettivo**: Esporre dati per query custom

**Endpoints da Creare**:

```dart
// Repository methods
class VideoAnalysisRepository {
  
  // Query tracking giocatore specifico
  Future<List<PlayerPosition>> getPlayerTracking(
    String analysisId, 
    String playerId
  );
  
  // Query eventi per tipo
  Future<List<MatchEvent>> getEventsByType(
    String analysisId, 
    String eventType
  );
  
  // Query metriche comparative
  Future<Map<String, PlayerMetrics>> comparePlayerMetrics(
    List<String> analysisIds
  );
  
  // Heatmap aggregata
  Future<HeatmapData> getTeamHeatmap(
    String analysisId, 
    String team
  );
  
  // Timeline eventi
  Future<List<MatchEvent>> getEventsTimeline(
    String analysisId,
    {double? startTime, double? endTime}
  );
}
```

---

#### Step 6.2: Visualizzazioni Interattive
**Obiettivo**: UI per esplorare dati strutturati

**Features da Implementare**:
- **Campo 2D interattivo**: Visualizza posizioni giocatori in tempo reale
- **Heatmap overlay**: Mostra zone più occupate
- **Timeline eventi**: Scrub video con eventi sincronizzati
- **Grafici metriche**: Distanza, velocità, possesso nel tempo
- **Comparazione giocatori**: Side-by-side metrics

**Tecnologie**: Flutter CustomPainter, fl_chart, video_player

---

## 💰 Stima Costi per Analisi

### Scenario: Video 10 minuti (600 secondi)

| Step | Tecnologia | Costo |
|------|-----------|-------|
| Estrazione frames (1 fps) | FFmpeg | $0.00 |
| Detection (600 frames) | YOLOv8 self-hosted | $0.00 |
| Team classification | K-Means | $0.00 |
| Tracking | DeepSORT | $0.00 |
| Coordinate mapping | OpenCV | $0.00 |
| Metriche base | Python | $0.00 |
| Analisi tattica LLM | Gemini Flash (~10K token) | $0.001 |
| **TOTALE** | | **~$0.001** |

### Confronto con Approccio Attuale:
- **Attuale** (Gemini Pro su video intero): ~$0.50-1.00 per 10 min
- **Nuovo** (Pipeline ottimizzata): ~$0.001 per 10 min
- **Risparmio**: **99.8%** 🎉

---

## 🛠️ Stack Tecnologico Consigliato

### Backend Processing
```yaml
Linguaggio: Python 3.11+
Framework: FastAPI / Flask
Video Processing: FFmpeg, OpenCV
ML Models:
  - YOLOv8 (Ultralytics)
  - DeepSORT
  - EasyOCR (opzionale)
Compute: 
  - Locale: GPU NVIDIA (RTX 3060+)
  - Cloud: Google Cloud Run (CPU) + Vertex AI (GPU on-demand)
```

### Frontend (Flutter)
```yaml
Visualizzazione: CustomPainter, fl_chart
Video: video_player, chewie
State Management: Riverpod
```

### Database
```yaml
Primary: Supabase (PostgreSQL)
Cache: Redis (per tracking data temporaneo)
Storage: Supabase Storage (frames, video)
```

---

## 📅 Timeline Implementazione

### Sprint 1 (2 settimane): MVP Detection & Tracking
- [ ] Setup backend Python con FastAPI
- [ ] Integrazione YOLOv8 per detection
- [ ] Implementazione DeepSORT per tracking
- [ ] API endpoint per upload video e processing
- [ ] Test su video sample

### Sprint 2 (2 settimane): Coordinate & Metriche
- [ ] Implementazione coordinate mapping
- [ ] Calcolo metriche base (distanza, velocità)
- [ ] Generazione heatmap
- [ ] Database schema per tracking data
- [ ] API per query dati strutturati

### Sprint 3 (2 settimane): Analisi Tattica & JSON
- [ ] Integrazione Gemini Flash per analisi
- [ ] Estensione schema JSON
- [ ] Event detection (passaggi, tiri)
- [ ] Generazione report completo
- [ ] Test comparativo costi

### Sprint 4 (1 settimana): UI & Visualizzazioni
- [ ] Campo 2D interattivo in Flutter
- [ ] Timeline eventi sincronizzata
- [ ] Grafici metriche
- [ ] Heatmap overlay
- [ ] Export dati (CSV, JSON)

### Sprint 5 (1 settimana): Ottimizzazioni & Deploy
- [ ] Ottimizzazione performance
- [ ] Caching intelligente
- [ ] Deploy backend su Cloud Run
- [ ] Monitoraggio costi
- [ ] Documentazione

**Totale: ~8 settimane**

---

## 🎯 Metriche di Successo

- ✅ Riduzione costi analisi: >95%
- ✅ Tempo processing: <2 min per 10 min video
- ✅ Accuratezza detection: >90%
- ✅ Accuratezza tracking: >85%
- ✅ Dati strutturati query-able: 100%
- ✅ Compatibilità JSON esistente: 100%

---

## 🔄 Fasi Future (Post-MVP)

### Fase 2: ML Avanzato
- [ ] Training custom model su dataset calcio
- [ ] Riconoscimento automatico formazioni
- [ ] Predizione movimenti giocatori
- [ ] Analisi automatica schemi tattici

### Fase 3: Real-time
- [ ] Processing video in streaming
- [ ] Analisi live durante partita
- [ ] Alert tattici in tempo reale

### Fase 4: Multi-camera
- [ ] Fusione dati da multiple angolazioni
- [ ] Ricostruzione 3D campo
- [ ] Tracking più accurato

---

## 📚 Risorse e Riferimenti

### Modelli Pre-trained
- YOLOv8: https://github.com/ultralytics/ultralytics
- DeepSORT: https://github.com/nwojke/deep_sort
- ByteTrack: https://github.com/ifzhang/ByteTrack
- Supervision: https://github.com/roboflow/supervision

### Dataset Calcio
- SoccerNet: https://www.soccer-net.org/
- ISSIA-CNR Soccer Dataset
- DFL Sports Analytics Dataset

### Papers Rilevanti
- "DeepSORT: Simple Online and Realtime Tracking"
- "YOLOv8: Real-Time Object Detection"
- "Tracking Football Players with Multiple Cameras"

---

## 🤝 Note Implementative

### Priorità
1. **Alta**: Detection + Tracking + Coordinate (core functionality)
2. **Media**: Metriche avanzate + Event detection
3. **Bassa**: OCR numeri maglia + Visualizzazioni fancy

### Rischi
- **Qualità video bassa**: Implementare pre-processing robusto
- **Occlusioni giocatori**: DeepSORT gestisce bene, ma test necessari
- **Costi GPU cloud**: Preferire self-hosted per MVP

### Raccomandazioni
- Iniziare con video di test di alta qualità
- Implementare logging dettagliato per debugging
- Creare dashboard monitoraggio costi
- Versioning modelli per rollback rapido
