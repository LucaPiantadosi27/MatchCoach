-- =====================================================================
-- Aggiunge match_id a video_analyses per collegare analisi a partite
-- =====================================================================

ALTER TABLE video_analyses
  ADD COLUMN IF NOT EXISTS match_id UUID REFERENCES matches(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_video_analyses_match_id ON video_analyses(match_id);
