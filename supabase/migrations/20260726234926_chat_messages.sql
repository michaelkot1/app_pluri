-- chat_messages (M6-02) — Ask Pluri history per SPEC §14 #66b / PLAN §1.3.
-- Owner-only RLS. Indefinite retention for v1. FK user_id → profiles CASCADE.

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  conversation_id uuid not null,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null,
  actions jsonb,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_user_id_idx
  on public.chat_messages (user_id);
create index if not exists chat_messages_conversation_id_idx
  on public.chat_messages (conversation_id);
create index if not exists chat_messages_user_id_created_at_idx
  on public.chat_messages (user_id, created_at);

alter table public.chat_messages enable row level security;

drop policy if exists chat_messages_select_own on public.chat_messages;
create policy chat_messages_select_own on public.chat_messages
  for select using ((select auth.uid()) = user_id);

drop policy if exists chat_messages_insert_own on public.chat_messages;
create policy chat_messages_insert_own on public.chat_messages
  for insert with check ((select auth.uid()) = user_id);

drop policy if exists chat_messages_update_own on public.chat_messages;
create policy chat_messages_update_own on public.chat_messages
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists chat_messages_delete_own on public.chat_messages;
create policy chat_messages_delete_own on public.chat_messages
  for delete using ((select auth.uid()) = user_id);
