-- =====================================================================
-- PromptIndo — Starter Categories Seed (§0.2 & §5.2)
-- =====================================================================

insert into public.categories (id, name, slug, icon, description, sort_order) values
  ('11111111-1111-4111-8111-111111111101', 'Writing',      'writing',      '✍️', 'Copywriting, storytelling, essays, emails, and creative writing prompts.', 1),
  ('11111111-1111-4111-8111-111111111102', 'Coding',       'coding',       '💻', 'Software engineering, debugging, code reviews, architecture, and SQL prompts.', 2),
  ('11111111-1111-4111-8111-111111111103', 'Design & Art', 'design-art',   '🎨', 'Image generation, UI/UX concepts, branding, illustration, and style prompts.', 3),
  ('11111111-1111-4111-8111-111111111104', 'Marketing',    'marketing',    '📣', 'SEO, social media campaigns, ad copy, growth experiments, and positioning.', 4),
  ('11111111-1111-4111-8111-111111111105', 'Business',     'business',     '💼', 'Strategy, pitch decks, operations, product management, and analysis.', 5),
  ('11111111-1111-4111-8111-111111111106', 'Education',    'education',    '🎓', 'Tutoring, study guides, lesson plans, explanations, and quiz generation.', 6),
  ('11111111-1111-4111-8111-111111111107', 'Productivity', 'productivity', '⚡', 'Summarization, workflows, planning, automation, and daily organization.', 7),
  ('11111111-1111-4111-8111-111111111108', 'Fun',          'fun',          '🎮', 'Games, roleplay, trivia, humor, and entertaining experiments.', 8)
on conflict (slug) do nothing;
