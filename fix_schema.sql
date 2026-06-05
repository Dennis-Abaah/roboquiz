-- ============================================================
-- RoboQuiz — Schema FIX Script
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor)
-- This fixes: empty profiles table + broken RLS policies
-- ============================================================

-- =========================
-- 1. AUTO-CREATE PROFILE ON SIGNUP (Trigger)
-- =========================
-- This function runs with elevated privileges when a new user 
-- is created in auth.users, bypassing RLS entirely.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, school, total_points)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'Student'),
    COALESCE(NEW.raw_user_meta_data->>'school', 'Unknown'),
    0
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists, then recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- =========================
-- 2. BACKFILL: Create profiles for existing users who are missing one
-- =========================
INSERT INTO public.profiles (id, username, school, total_points)
SELECT 
  u.id,
  COALESCE(u.raw_user_meta_data->>'username', 'Student'),
  COALESCE(u.raw_user_meta_data->>'school', 'Unknown'),
  0
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL;


-- =========================
-- 3. FIX RLS POLICIES — use auth.uid() IS NOT NULL
-- =========================

-- ─── Quizzes ───
DROP POLICY IF EXISTS "Quizzes are viewable by authenticated users" ON public.quizzes;
CREATE POLICY "Quizzes are viewable by authenticated users"
  ON public.quizzes FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can insert quizzes" ON public.quizzes;
DROP POLICY IF EXISTS "Only admin can insert quizzes" ON public.quizzes;
CREATE POLICY "Only admin can insert quizzes"
  ON public.quizzes FOR INSERT
  WITH CHECK (auth.jwt()->>'email' = 'abaahdennis54@gmail.com');

-- Allow quiz deletion (admin only)
DROP POLICY IF EXISTS "Authenticated users can delete quizzes" ON public.quizzes;
DROP POLICY IF EXISTS "Only admin can delete quizzes" ON public.quizzes;
CREATE POLICY "Only admin can delete quizzes"
  ON public.quizzes FOR DELETE
  USING (auth.jwt()->>'email' = 'abaahdennis54@gmail.com');

-- ─── Questions ───
DROP POLICY IF EXISTS "Questions are viewable by authenticated users" ON public.questions;
CREATE POLICY "Questions are viewable by authenticated users"
  ON public.questions FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can insert questions" ON public.questions;
DROP POLICY IF EXISTS "Only admin can insert questions" ON public.questions;
CREATE POLICY "Only admin can insert questions"
  ON public.questions FOR INSERT
  WITH CHECK (auth.jwt()->>'email' = 'abaahdennis54@gmail.com');

-- Allow question deletion (admin only)
DROP POLICY IF EXISTS "Authenticated users can delete questions" ON public.questions;
DROP POLICY IF EXISTS "Only admin can delete questions" ON public.questions;
CREATE POLICY "Only admin can delete questions"
  ON public.questions FOR DELETE
  USING (auth.jwt()->>'email' = 'abaahdennis54@gmail.com');

-- ─── Submissions ───
DROP POLICY IF EXISTS "Users can view their own submissions" ON public.submissions;
CREATE POLICY "Users can view their own submissions"
  ON public.submissions FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own submissions" ON public.submissions;
CREATE POLICY "Users can insert their own submissions"
  ON public.submissions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ─── Profiles (ensure these exist properly) ───
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);


-- =========================
-- 4. RE-CREATE increment_points RPC (ensure it exists)
-- =========================
CREATE OR REPLACE FUNCTION public.increment_points(row_id UUID, amount INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET total_points = total_points + amount
  WHERE id = row_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =========================
-- DONE! Verify by checking:
-- SELECT * FROM public.profiles;
-- =========================
