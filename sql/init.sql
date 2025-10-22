create table if not exists messages (
  id bigserial primary key,
  conversation_id text not null,
  role text not null check (role in ('user','assistant','system')),
  content text not null,
  ts timestamptz not null default now()
);
create index if not exists idx_messages_conv_ts
  on messages(conversation_id, ts);
