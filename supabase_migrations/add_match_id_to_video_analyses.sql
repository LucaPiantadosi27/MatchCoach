-- Aggiungi colonna match_id alla tabella video_analyses per associare le analisi alle partite
ALTER TABLE video_analyses 
ADD COLUMN IF NOT EXISTS match_id UUID REFERENCES matches(id) ON DELETE CASCADE;

-- Indice per query veloci per partita
CREATE INDEX IF NOT EXISTS idx_video_analyses_match_id ON video_analyses(match_id);

-- Commento sulla colonna
COMMENT ON COLUMN video_analyses.match_id IS 'ID della partita a cui è associata questa analisi video';
