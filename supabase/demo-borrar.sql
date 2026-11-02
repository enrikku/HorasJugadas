-- Horas Jugadas - borrar los datos de DEMO
-- Elimina solo los jugadores cuyo apodo termina en " (demo)".
-- Sus días, personajes y tokens se borran solos (on delete cascade).
-- Los jugadores reales NO se tocan.
-- Ejecutar en: Supabase > SQL Editor > New query > Run

delete from public.players
where nick like '% (demo)'
returning nick as jugador_borrado;
