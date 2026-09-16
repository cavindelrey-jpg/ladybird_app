-- Migration to support school-specific subjects for internal management.
-- The global 'kAcademicSubjects' is too broad (Mathematics, Science) for
-- a real school's timetable/marks (Chemistry, Biology, Home Economics).

CREATE TABLE public.school_subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id TEXT NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(school_id, name)
);

ALTER TABLE public.school_subjects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "school_subjects_select" ON public.school_subjects
    FOR SELECT USING (true); -- Everyone can read school subjects

CREATE POLICY "school_subjects_insert" ON public.school_subjects
    FOR INSERT WITH CHECK (public.has_min_role('school_admin'::user_role));

CREATE POLICY "school_subjects_delete" ON public.school_subjects
    FOR DELETE USING (public.has_min_role('school_admin'::user_role));

-- Insert some default subjects for Greenhills (id: ladybird)
INSERT INTO public.school_subjects (school_id, name) VALUES
('ladybird', 'Mathematics'),
('ladybird', 'English Language'),
('ladybird', 'French'),
('ladybird', 'Physics'),
('ladybird', 'Chemistry'),
('ladybird', 'Biology'),
('ladybird', 'Economics'),
('ladybird', 'Geography'),
('ladybird', 'History'),
('ladybird', 'Computer Science'),
('ladybird', 'Citizenship'),
('ladybird', 'Literature in English'),
('ladybird', 'Accounting'),
('ladybird', 'Commerce'),
('ladybird', 'Home Economics');
