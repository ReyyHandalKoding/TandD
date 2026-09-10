-- TandD full backend
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text,
  bio text default '',
  website text default '',
  avatar_url text,
  banner_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  content text default '',
  media_type text check (media_type in ('image','video') or media_type is null),
  media_url text,
  media_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(post_id,user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(follower_id,following_id),
  check(follower_id<>following_id)
);

create table if not exists public.reposts (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(post_id,user_id)
);

create table if not exists public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(post_id,user_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'dm',
  created_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(conversation_id,user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  content text default '',
  media_url text,
  created_at timestamptz not null default now(),
  edited_at timestamptz
);

create table if not exists public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(blocker_id,blocked_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete cascade,
  reason text not null,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create index if not exists posts_created_idx on public.posts(created_at desc);
create index if not exists posts_author_idx on public.posts(author_id);
create index if not exists comments_post_idx on public.comments(post_id);
create index if not exists messages_conv_idx on public.messages(conversation_id,created_at);
create index if not exists profiles_username_idx on public.profiles(username);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
declare base text; candidate text;
begin
  base := lower(regexp_replace(split_part(coalesce(new.email,'user'),'@',1),'[^a-zA-Z0-9_]','','g'));
  if base='' then base:='user'; end if;
  candidate:=left(base,28);
  while exists(select 1 from public.profiles where username=candidate) loop
    candidate:=left(base,23)||substr(md5(random()::text),1,5);
  end loop;
  insert into public.profiles(id,username,display_name)
  values(new.id,candidate,base);
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;
alter table public.reposts enable row level security;
alter table public.bookmarks enable row level security;
alter table public.notifications enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;

-- SECURITY DEFINER helper avoids recursive RLS checks on conversation_members.
create or replace function public.is_conversation_member(cid uuid, uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.conversation_members where conversation_id=cid and user_id=uid) $$;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select using (true);
drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles for insert with check (auth.uid()=id);
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update using (auth.uid()=id) with check (auth.uid()=id);

drop policy if exists posts_select on public.posts;
create policy posts_select on public.posts for select using (true);
drop policy if exists posts_insert on public.posts;
create policy posts_insert on public.posts for insert with check (auth.uid()=author_id);
drop policy if exists posts_update on public.posts;
create policy posts_update on public.posts for update using (auth.uid()=author_id) with check (auth.uid()=author_id);
drop policy if exists posts_delete on public.posts;
create policy posts_delete on public.posts for delete using (auth.uid()=author_id);

drop policy if exists likes_all on public.likes;
create policy likes_all on public.likes for all using (auth.uid()=user_id) with check (auth.uid()=user_id);

drop policy if exists comments_select on public.comments;
create policy comments_select on public.comments for select using (true);
drop policy if exists comments_write on public.comments;
create policy comments_write on public.comments for insert with check (auth.uid()=user_id);
drop policy if exists comments_update on public.comments;
create policy comments_update on public.comments for update using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists comments_delete on public.comments;
create policy comments_delete on public.comments for delete using (auth.uid()=user_id);

drop policy if exists follows_select on public.follows;
create policy follows_select on public.follows for select using (true);
drop policy if exists follows_write on public.follows;
create policy follows_write on public.follows for all using (auth.uid()=follower_id) with check (auth.uid()=follower_id);

drop policy if exists reposts_all on public.reposts;
create policy reposts_all on public.reposts for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists bookmarks_all on public.bookmarks;
create policy bookmarks_all on public.bookmarks for all using (auth.uid()=user_id) with check (auth.uid()=user_id);

drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications for select using (auth.uid()=user_id);
drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications for update using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists notifications_insert on public.notifications;
create policy notifications_insert on public.notifications for insert with check (auth.uid()=actor_id);

drop policy if exists conv_select on public.conversations;
create policy conv_select on public.conversations for select using (public.is_conversation_member(id,auth.uid()));
drop policy if exists conv_insert on public.conversations;
create policy conv_insert on public.conversations for insert with check (auth.uid() is not null);

drop policy if exists members_select on public.conversation_members;
create policy members_select on public.conversation_members for select using (public.is_conversation_member(conversation_id,auth.uid()));
drop policy if exists members_insert on public.conversation_members;
create policy members_insert on public.conversation_members for insert with check (auth.uid() is not null);

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages for select using (public.is_conversation_member(conversation_id,auth.uid()));
drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages for insert with check (auth.uid()=sender_id and public.is_conversation_member(conversation_id,auth.uid()));
drop policy if exists messages_update on public.messages;
create policy messages_update on public.messages for update using (auth.uid()=sender_id);
drop policy if exists messages_delete on public.messages;
create policy messages_delete on public.messages for delete using (auth.uid()=sender_id);

drop policy if exists blocks_all on public.blocks;
create policy blocks_all on public.blocks for all using (auth.uid()=blocker_id) with check (auth.uid()=blocker_id);

drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports for insert with check (auth.uid()=reporter_id);
drop policy if exists reports_select on public.reports;
create policy reports_select on public.reports for select using (auth.uid()=reporter_id);

-- Storage buckets
insert into storage.buckets(id,name,public) values ('avatars','avatars',true) on conflict(id) do nothing;
insert into storage.buckets(id,name,public) values ('banners','banners',true) on conflict(id) do nothing;
insert into storage.buckets(id,name,public) values ('media','media',false) on conflict(id) do nothing;

drop policy if exists avatars_read on storage.objects;
create policy avatars_read on storage.objects for select using (bucket_id='avatars');
drop policy if exists avatars_write on storage.objects;
create policy avatars_write on storage.objects for insert with check (bucket_id='avatars' and auth.uid()::text=(storage.foldername(name))[1]);
drop policy if exists avatars_update on storage.objects;
create policy avatars_update on storage.objects for update using (bucket_id='avatars' and auth.uid()::text=(storage.foldername(name))[1]);

drop policy if exists banners_read on storage.objects;
create policy banners_read on storage.objects for select using (bucket_id='banners');
drop policy if exists banners_write on storage.objects;
create policy banners_write on storage.objects for insert with check (bucket_id='banners' and auth.uid()::text=(storage.foldername(name))[1]);
drop policy if exists banners_update on storage.objects;
create policy banners_update on storage.objects for update using (bucket_id='banners' and auth.uid()::text=(storage.foldername(name))[1]);

drop policy if exists media_read on storage.objects;
create policy media_read on storage.objects for select using (bucket_id='media' and auth.uid() is not null);
drop policy if exists media_write on storage.objects;
create policy media_write on storage.objects for insert with check (bucket_id='media' and auth.uid()::text=(storage.foldername(name))[1]);
drop policy if exists media_update on storage.objects;
create policy media_update on storage.objects for update using (bucket_id='media' and auth.uid()::text=(storage.foldername(name))[1]);
drop policy if exists media_delete on storage.objects;
create policy media_delete on storage.objects for delete using (bucket_id='media' and auth.uid()::text=(storage.foldername(name))[1]);

-- Enable realtime for chat
do $$
begin
  begin
    alter publication supabase_realtime add table public.messages;
  exception when duplicate_object then null;
  end;
end $$;

-- TandD v4 stability + notifications + DM helper
-- Safe to run after the existing schema. It also repairs older deployments.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='posts' AND column_name='user_id') THEN
    EXECUTE 'ALTER TABLE public.posts ALTER COLUMN user_id SET DEFAULT auth.uid()';
  END IF;
END $$;

ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS kind text DEFAULT 'dm';

-- Secure DM creation/finding. The function performs the two-member lookup
-- without exposing other members through client-side RLS queries.
CREATE OR REPLACE FUNCTION public.find_or_create_dm(other_user uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE
  me uuid := auth.uid();
  cid uuid;
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF other_user IS NULL OR other_user = me THEN RAISE EXCEPTION 'Invalid chat target'; END IF;

  SELECT c.id INTO cid
  FROM public.conversations c
  WHERE c.kind='dm'
    AND EXISTS (SELECT 1 FROM public.conversation_members a WHERE a.conversation_id=c.id AND a.user_id=me)
    AND EXISTS (SELECT 1 FROM public.conversation_members b WHERE b.conversation_id=c.id AND b.user_id=other_user)
    AND (SELECT count(*) FROM public.conversation_members z WHERE z.conversation_id=c.id)=2
  LIMIT 1;

  IF cid IS NULL THEN
    INSERT INTO public.conversations(kind) VALUES ('dm') RETURNING id INTO cid;
    INSERT INTO public.conversation_members(conversation_id,user_id) VALUES (cid,me),(cid,other_user);
  END IF;
  RETURN cid;
END $$;

GRANT EXECUTE ON FUNCTION public.find_or_create_dm(uuid) TO authenticated;

-- Notification trigger helpers. They run server-side so a client cannot
-- accidentally prevent the recipient from receiving an activity notification.
CREATE OR REPLACE FUNCTION public.tandd_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE recipient uuid; actor uuid; msg text; p uuid;
BEGIN
  IF TG_TABLE_NAME='likes' THEN
    SELECT author_id INTO recipient FROM public.posts WHERE id=NEW.post_id;
    actor:=NEW.user_id; p:=NEW.post_id; msg:='menyukai postinganmu.';
  ELSIF TG_TABLE_NAME='comments' THEN
    SELECT author_id INTO recipient FROM public.posts WHERE id=NEW.post_id;
    actor:=NEW.user_id; p:=NEW.post_id; msg:='mengomentari postinganmu.';
  ELSIF TG_TABLE_NAME='reposts' THEN
    SELECT author_id INTO recipient FROM public.posts WHERE id=NEW.post_id;
    actor:=NEW.user_id; p:=NEW.post_id; msg:='merepost postinganmu.';
  ELSIF TG_TABLE_NAME='follows' THEN
    recipient:=NEW.following_id; actor:=NEW.follower_id; msg:='mulai mengikuti kamu.';
  ELSIF TG_TABLE_NAME='messages' THEN
    actor:=NEW.sender_id;
    FOR recipient IN
      SELECT user_id FROM public.conversation_members
      WHERE conversation_id=NEW.conversation_id AND user_id<>actor
    LOOP
      INSERT INTO public.notifications(user_id,actor_id,type,payload)
      VALUES(recipient,actor,'message',jsonb_build_object('conversation_id',NEW.conversation_id,'message_id',NEW.id,'message',coalesce((SELECT display_name FROM public.profiles WHERE id=actor),(SELECT username FROM public.profiles WHERE id=actor),'Seseorang')||' mengirim pesan.'));
    END LOOP;
    RETURN NEW;
  ELSE RETURN NEW;
  END IF;

  IF recipient IS NOT NULL AND actor IS NOT NULL AND recipient<>actor THEN
    INSERT INTO public.notifications(user_id,actor_id,type,payload)
    VALUES(recipient,actor,TG_TABLE_NAME,jsonb_build_object('post_id',p,'message',coalesce((SELECT display_name FROM public.profiles WHERE id=actor),(SELECT username FROM public.profiles WHERE id=actor),'Seseorang')||' '||msg));
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS tandd_notify_like ON public.likes;
CREATE TRIGGER tandd_notify_like AFTER INSERT ON public.likes FOR EACH ROW EXECUTE FUNCTION public.tandd_notify();
DROP TRIGGER IF EXISTS tandd_notify_comment ON public.comments;
CREATE TRIGGER tandd_notify_comment AFTER INSERT ON public.comments FOR EACH ROW EXECUTE FUNCTION public.tandd_notify();
DROP TRIGGER IF EXISTS tandd_notify_repost ON public.reposts;
CREATE TRIGGER tandd_notify_repost AFTER INSERT ON public.reposts FOR EACH ROW EXECUTE FUNCTION public.tandd_notify();
DROP TRIGGER IF EXISTS tandd_notify_follow ON public.follows;
CREATE TRIGGER tandd_notify_follow AFTER INSERT ON public.follows FOR EACH ROW EXECUTE FUNCTION public.tandd_notify();
DROP TRIGGER IF EXISTS tandd_notify_message ON public.messages;
CREATE TRIGGER tandd_notify_message AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.tandd_notify();

-- Let the notification feed update instantly.
DO $$
BEGIN
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

NOTIFY pgrst, 'reload schema';

