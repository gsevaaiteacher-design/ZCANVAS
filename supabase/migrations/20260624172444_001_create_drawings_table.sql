-- Create drawings table
CREATE TABLE IF NOT EXISTS drawings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  canvas_data TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE drawings ENABLE ROW LEVEL SECURITY;

-- Create policies for public access (no auth required for this demo)
CREATE POLICY "select_drawings" ON drawings FOR SELECT
  USING (true);

CREATE POLICY "insert_drawings" ON drawings FOR INSERT
  WITH CHECK (true);

CREATE POLICY "update_drawings" ON drawings FOR UPDATE
  USING (true);

CREATE POLICY "delete_drawings" ON drawings FOR DELETE
  USING (true);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS drawings_updated_at_idx ON drawings (updated_at DESC);
