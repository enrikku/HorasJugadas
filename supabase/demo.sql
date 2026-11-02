-- Horas Jugadas - datos de DEMO
-- Crea 6 jugadores ficticios con ~45 días de actividad para ver cómo queda la web.
-- Ejecutar en: Supabase > SQL Editor > New query > Run
--
-- * Todos los apodos terminan en " (demo)", así no chocan con jugadores reales
--   y se borran limpiamente con demo-borrar.sql.
-- * Las fechas son relativas a hoy: la demo siempre se ve "actual".
-- * Se puede ejecutar varias veces: no duplica nada. Para regenerarla, ejecuta
--   antes demo-borrar.sql.

begin;

select setseed(0.42); -- mismos números "aleatorios" en cada ejecución

-- Jugadores ------------------------------------------------------------------
insert into public.players (nick, updated_at) values
    ('Ana (demo)',   now() - interval '20 minutes'),
    ('Bruno (demo)', now() - interval '2 hours'),
    ('Carla (demo)', now() - interval '1 day'),
    ('Dani (demo)',  now() - interval '3 hours'),
    ('Elena (demo)', now() - interval '8 days'),
    ('Fer (demo)',   now() - interval '40 minutes')
on conflict (nick) do nothing;

-- Token imposible de adivinar: nadie puede "reclamar" un apodo de la demo con el uploader.
insert into public.player_tokens (nick, token_hash)
select nick, 'demo-no-reclamable' from public.players where nick like '% (demo)'
on conflict (nick) do nothing;

-- Horas por día ----------------------------------------------------------------
-- Cada jugador tiene un perfil:
--   h_semana / h_finde: horas medias entre semana / fin de semana
--   prob:  probabilidad de jugar un día cualquiera
--   desde: empezó a jugar hace N días   ·   hasta: dejó de jugar hace N días
with perfil (nick, h_semana, h_finde, prob, desde, hasta) as (values
    ('Ana (demo)',   4.0, 7.0, 0.95, 45, 0),   -- muy activa todos los días
    ('Bruno (demo)', 0.8, 6.0, 0.55, 45, 0),   -- juega sobre todo el finde
    ('Carla (demo)', 2.5, 3.5, 0.75, 45, 1),   -- regular, hoy aún no ha jugado
    ('Dani (demo)',  3.0, 2.0, 0.70, 45, 0),   -- más entre semana (bandas)
    ('Elena (demo)', 5.0, 6.0, 0.90, 45, 8),   -- jugaba mucho, lo dejó hace 8 días
    ('Fer (demo)',   3.0, 5.0, 0.90, 10, 0)    -- empezó hace 10 días
),
dias as (
    select generate_series(0, 44) as hace
)
insert into public.play_days (nick, day, seconds)
select
    p.nick,
    current_date - d.hace,
    least(86400, round(
        3600
        * (case when extract(isodow from current_date - d.hace) in (6, 7) then p.h_finde else p.h_semana end)
        * (0.5 + random())                         -- variación de ±50 %
        * (case when d.hace = 0 then 0.4 else 1 end) -- hoy el día va por la mitad
    ))::int
from perfil p
cross join dias d
where d.hace < p.desde
  and d.hace >= p.hasta
  and random() < p.prob
on conflict (nick, day) do nothing;

-- Personajes -------------------------------------------------------------------
insert into public.characters (nick, char_key, class, level, played_seconds, last_seen) values
    ('Ana (demo)',   'Lunaria-Sanguino',     'PRIEST',      80, 3600 * 1840, now() - interval '20 minutes'),
    ('Ana (demo)',   'Kragnor-Sanguino',     'WARRIOR',     80, 3600 * 960,  now() - interval '2 days'),
    ('Ana (demo)',   'Chispita-Tyrande',     'MAGE',        74, 3600 * 210,  now() - interval '6 days'),
    ('Bruno (demo)', 'Garrafón-Dun Modr',    'HUNTER',      80, 3600 * 1120, now() - interval '2 hours'),
    ('Bruno (demo)', 'Zarpazo-Dun Modr',     'DRUID',       80, 3600 * 430,  now() - interval '9 days'),
    ('Carla (demo)', 'Sombraluz-Minahonda',  'PALADIN',     80, 3600 * 1390, now() - interval '1 day'),
    ('Carla (demo)', 'Escamita-Minahonda',   'EVOKER',      80, 3600 * 520,  now() - interval '3 days'),
    ('Carla (demo)', 'Pocapena-Exodar',      'ROGUE',       58, 3600 * 95,   now() - interval '20 days'),
    ('Carla (demo)', 'Tótem-Exodar',         'SHAMAN',      35, 3600 * 41,   now() - interval '30 days'),
    ('Dani (demo)',  'Mortaja-Uldum',        'DEATHKNIGHT', 80, 3600 * 2210, now() - interval '3 hours'),
    ('Dani (demo)',  'Ojovil-Uldum',         'DEMONHUNTER', 80, 3600 * 610,  now() - interval '4 days'),
    ('Elena (demo)', 'Fëlicia-Los Errantes', 'WARLOCK',     80, 3600 * 2650, now() - interval '8 days'),
    ('Elena (demo)', 'Bambú-Los Errantes',   'MONK',        80, 3600 * 780,  now() - interval '12 days'),
    ('Fer (demo)',   'Novato-Sanguino',      'PALADIN',     47, 3600 * 38,   now() - interval '40 minutes'),
    ('Fer (demo)',   'Flechita-Sanguino',    'HUNTER',      21, 3600 * 9,    now() - interval '3 days')
on conflict (nick, char_key) do nothing;

commit;

-- Resumen
select p.nick,
       count(distinct d.day)                    as dias_jugados,
       round(sum(d.seconds) / 3600.0, 1)        as horas_45_dias,
       (select count(*) from public.characters c where c.nick = p.nick) as personajes
from public.players p
left join public.play_days d on d.nick = p.nick
where p.nick like '% (demo)'
group by p.nick
order by horas_45_dias desc nulls last;
