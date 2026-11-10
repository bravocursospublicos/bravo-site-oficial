-- BRAVO Preparatório Policial — biblioteca de conteúdos
-- Execute no SQL Editor do MESMO projeto Supabase usado pelo site.
-- Requer a tabela public.profiles e a função public.is_bravo_admin()
-- criadas na configuração anterior do login.

create table if not exists public.course_contents (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 160),
  description text not null default '',
  content_type text not null check (content_type in ('video','booklet','note')),
  drive_url text,
  course text not null default 'Ambos os cursos',
  is_published boolean not null default false,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint course_contents_link_or_note check (
    content_type = 'note' or drive_url is not null
  )
);

create index if not exists course_contents_published_idx
  on public.course_contents (is_published, content_type, created_at desc);

alter table public.course_contents enable row level security;

drop policy if exists "Admins manage course contents" on public.course_contents;
create policy "Admins manage course contents"
on public.course_contents
for all
to authenticated
using (public.is_bravo_admin())
with check (public.is_bravo_admin());

drop policy if exists "Students read published course contents" on public.course_contents;
create policy "Students read published course contents"
on public.course_contents
for select
to authenticated
using (
  is_published = true
  and (
    course = 'Ambos os cursos'
    or course = (select p.course from public.profiles p where p.id = auth.uid())
  )
);

grant select, insert, update, delete on public.course_contents to authenticated;

-- Observação: os arquivos permanecem no Google Drive.
-- O site armazena somente o link e os metadados no Supabase.
-- Compartilhe cada arquivo como "Qualquer pessoa com o link — Leitor"
-- ou use uma pasta/Drive institucional com permissões adequadas.
