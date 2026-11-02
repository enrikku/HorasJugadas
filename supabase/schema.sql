-- Horas Jugadas - esquema de Supabase
-- Ejecutar entero en: Supabase > SQL Editor > New query > Run
--
-- Seguridad:
--   * Cualquiera con la clave "anon" puede LEER (la web es pública para el grupo).
--   * Nadie puede escribir directamente en las tablas.
--   * Solo se escribe con la función upload_play_data(), que exige un token secreto.
--     La primera vez que un apodo sube datos, queda "reclamado" con su token;
--     a partir de ahí solo ese uploader puede actualizarlo.

-- Tablas -------------------------------------------------------------------

create table if not exists public.players (
    nick        text primary key check (char_length(nick) between 1 and 24),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

create table if not exists public.play_days (
    nick     text not null references public.players(nick) on delete cascade,
    day      date not null,
    seconds  integer not null check (seconds between 0 and 86400),
    primary key (nick, day)
);

create table if not exists public.characters (
    nick            text not null references public.players(nick) on delete cascade,
    char_key        text not null,          -- "Personaje-Reino"
    class           text,                   -- "MAGE", "PRIEST"...
    level           integer,
    played_seconds  bigint not null default 0,
    last_seen       timestamptz,
    primary key (nick, char_key)
);

-- Tokens (privado: sin políticas => la clave anon no puede verlo)
create table if not exists public.player_tokens (
    nick        text primary key references public.players(nick) on delete cascade,
    token_hash  text not null
);

-- Seguridad (RLS) ------------------------------------------------------------

alter table public.players       enable row level security;
alter table public.play_days     enable row level security;
alter table public.characters    enable row level security;
alter table public.player_tokens enable row level security;

drop policy if exists "lectura publica" on public.players;
drop policy if exists "lectura publica" on public.play_days;
drop policy if exists "lectura publica" on public.characters;
create policy "lectura publica" on public.players    for select to anon, authenticated using (true);
create policy "lectura publica" on public.play_days  for select to anon, authenticated using (true);
create policy "lectura publica" on public.characters for select to anon, authenticated using (true);

-- Función de subida ------------------------------------------------------------
-- p_days:  {"2026-11-02": 3600, "2026-11-01": 5400}
-- p_chars: [{"char_key": "Pj-Reino", "class": "MAGE", "level": 80,
--            "played_seconds": 123456, "last_seen": 1793600000}]

create or replace function public.upload_play_data(
    p_nick  text,
    p_token text,
    p_days  jsonb,
    p_chars jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_hash     text := encode(sha256(convert_to(coalesce(p_token, ''), 'UTF8')), 'hex');
    v_existing text;
begin
    if p_nick is null or char_length(trim(p_nick)) = 0 or char_length(p_nick) > 24 then
        raise exception 'Apodo no válido';
    end if;
    if p_token is null or char_length(p_token) < 32 then
        raise exception 'Token no válido';
    end if;

    select token_hash into v_existing from player_tokens where nick = p_nick;

    if v_existing is null then
        insert into players (nick) values (p_nick) on conflict (nick) do nothing;
        insert into player_tokens (nick, token_hash) values (p_nick, v_hash);
    elsif v_existing <> v_hash then
        raise exception 'El apodo "%" ya pertenece a otra persona', p_nick;
    end if;

    insert into play_days (nick, day, seconds)
    select p_nick, e.key::date, least(86400, greatest(0, round(e.value::numeric)))::int
    from jsonb_each_text(coalesce(p_days, '{}'::jsonb)) as e
    on conflict (nick, day) do update set seconds = excluded.seconds;

    insert into characters (nick, char_key, class, level, played_seconds, last_seen)
    select p_nick, c.char_key, nullif(c.class, ''), c.level,
           greatest(0, round(c.played_seconds))::bigint,
           case when c.last_seen > 0 then to_timestamp(c.last_seen) end
    from jsonb_to_recordset(coalesce(p_chars, '[]'::jsonb))
         as c(char_key text, class text, level int, played_seconds numeric, last_seen bigint)
    where c.char_key is not null and c.char_key <> ''
    on conflict (nick, char_key) do update set
        class          = excluded.class,
        level          = excluded.level,
        played_seconds = excluded.played_seconds,
        last_seen      = excluded.last_seen;

    update players set updated_at = now() where nick = p_nick;
end;
$$;

revoke all on function public.upload_play_data(text, text, jsonb, jsonb) from public;
grant execute on function public.upload_play_data(text, text, jsonb, jsonb) to anon, authenticated;

-- Si alguien pierde su token (reinstala Windows, etc.), el administrador
-- puede liberar su apodo ejecutando:
--   delete from public.player_tokens where nick = 'Apodo';
