-- ============================================================
-- RoboQuiz — Microbit Upgrade Migration
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- 1. Update the quizzes category constraint to allow 'Microbit'
ALTER TABLE public.quizzes DROP CONSTRAINT IF EXISTS quizzes_category_check;
ALTER TABLE public.quizzes ADD CONSTRAINT quizzes_category_check CHECK (category IN ('EV3', 'Spike', 'Whalesbot', 'Microbit'));

-- 2. Update Admin Policies to allow joshua@gmail.com
DROP POLICY IF EXISTS "Only admin can insert quizzes" ON public.quizzes;
CREATE POLICY "Only admin can insert quizzes"
  ON public.quizzes FOR INSERT
  WITH CHECK (auth.jwt()->>'email' IN ('abaahdennis54@gmail.com', 'joshua@gmail.com'));

DROP POLICY IF EXISTS "Only admin can delete quizzes" ON public.quizzes;
CREATE POLICY "Only admin can delete quizzes"
  ON public.quizzes FOR DELETE
  USING (auth.jwt()->>'email' IN ('abaahdennis54@gmail.com', 'joshua@gmail.com'));

DROP POLICY IF EXISTS "Only admin can insert questions" ON public.questions;
CREATE POLICY "Only admin can insert questions"
  ON public.questions FOR INSERT
  WITH CHECK (auth.jwt()->>'email' IN ('abaahdennis54@gmail.com', 'joshua@gmail.com'));

DROP POLICY IF EXISTS "Only admin can delete questions" ON public.questions;
CREATE POLICY "Only admin can delete questions"
  ON public.questions FOR DELETE
  USING (auth.jwt()->>'email' IN ('abaahdennis54@gmail.com', 'joshua@gmail.com'));
