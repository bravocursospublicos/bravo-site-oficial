-- BRAVO Preparatório Policial — estrutura inicial de autenticação e perfis
-- Execute no SQL Editor do projeto Supabase.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  role text not null default 'student' check (role in ('admin','student')),
  course text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create or replace function public.is_bravo_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

drop policy if exists "profiles_read_own_or_admin" on public.profiles;
create policy "profiles_read_own_or_admin"
on public.profiles for select to authenticated
using (id = auth.uid() or public.is_bravo_admin());

drop policy if exists "profiles_admin_update" on public.profiles;
create policy "profiles_admin_update"
on public.profiles for update to authenticated
using (public.is_bravo_admin())
with check (public.is_bravo_admin());

create or replace function public.handle_new_bravo_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, role, course)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    'student',
    new.raw_user_meta_data->>'course'
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        email = excluded.email,
        course = excluded.course;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_bravo on auth.users;
create trigger on_auth_user_created_bravo
after insert on auth.users
for each row execute procedure public.handle_new_bravo_user();

-- PASSO DE SEGURANÇA: depois de criar sua conta de administrador em
-- Authentication > Users, copie o UUID dela e execute:
-- update public.profiles set role = 'admin' where id = 'UUID-DA-CONTA-ADMIN';
-- Não promova alunos a administrador pelo formulário público.
