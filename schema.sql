-- ============================================================
-- RoboQuiz — Supabase Schema Migration
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- =========================
-- 1. PROFILES TABLE
-- =========================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  school TEXT NOT NULL,
  total_points INTEGER NOT NULL DEFAULT 0
);

-- Index for leaderboard sorting
CREATE INDEX IF NOT EXISTS idx_profiles_total_points ON public.profiles (total_points DESC);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can read profiles (leaderboard needs this)
CREATE POLICY "Profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

-- Users can insert their own profile
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- =========================
-- 2. QUIZZES TABLE
-- =========================
CREATE TABLE IF NOT EXISTS public.quizzes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  category TEXT NOT NULL CHECK (category IN ('EV3', 'Spike', 'Whalesbot')),
  title TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read quizzes
CREATE POLICY "Quizzes are viewable by authenticated users"
  ON public.quizzes FOR SELECT
  USING (auth.role() = 'authenticated');

-- Authenticated users can insert quizzes (admin creates them)
CREATE POLICY "Authenticated users can insert quizzes"
  ON public.quizzes FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- =========================
-- 3. QUESTIONS TABLE
-- =========================
CREATE TABLE IF NOT EXISTS public.questions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  quiz_id BIGINT NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,
  correct_option CHAR(1) NOT NULL CHECK (correct_option IN ('A', 'B', 'C', 'D'))
);

-- Index for fetching questions by quiz
CREATE INDEX IF NOT EXISTS idx_questions_quiz_id ON public.questions (quiz_id);

-- Enable RLS
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read questions
CREATE POLICY "Questions are viewable by authenticated users"
  ON public.questions FOR SELECT
  USING (auth.role() = 'authenticated');

-- Authenticated users can insert questions (admin creates them)
CREATE POLICY "Authenticated users can insert questions"
  ON public.questions FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- =========================
-- 4. SUBMISSIONS TABLE
-- =========================
CREATE TABLE IF NOT EXISTS public.submissions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  quiz_id BIGINT NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
  question_id BIGINT NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  is_correct BOOLEAN NOT NULL DEFAULT false,

  -- Prevent duplicate submissions for the same question
  CONSTRAINT unique_user_question UNIQUE (user_id, question_id)
);

-- Index for fast duplicate checks
CREATE INDEX IF NOT EXISTS idx_submissions_user_question ON public.submissions (user_id, question_id);

-- Index for fetching user submissions per quiz
CREATE INDEX IF NOT EXISTS idx_submissions_user_quiz ON public.submissions (user_id, quiz_id);

-- Enable RLS
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;

-- Users can read their own submissions
CREATE POLICY "Users can view their own submissions"
  ON public.submissions FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own submissions
CREATE POLICY "Users can insert their own submissions"
  ON public.submissions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- =========================
-- 5. ENABLE REALTIME FOR PROFILES
-- =========================
-- This enables the real-time listener for leaderboard updates
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;

-- =========================
-- 6. RPC: INCREMENT POINTS
-- =========================
-- Safely increments total_points by a given amount
CREATE OR REPLACE FUNCTION public.increment_points(row_id UUID, amount INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET total_points = total_points + amount
  WHERE id = row_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
