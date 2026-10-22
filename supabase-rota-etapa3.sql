-- =====================================================================
-- Banheza Rota — ETAPA 3 (agenda de visitas)
-- Rode no SQL Editor do projeto Supabase do Assist, DEPOIS dos arquivos anteriores do Rota.
-- É seguro rodar de novo: nada é apagado nem duplicado.
--
-- Cria a tabela rota_visitas: cada visita agendada/realizada, com data, hora, as empresas
-- representadas (uma ou mais), assunto, resultado, anotações e a posição de GPS do registro.
-- Regras de segurança: cada pessoa só vê e altera as próprias visitas.
--
-- NÃO mexe em nada do Assist.
-- COMO DESFAZER:  drop table if exists rota_visitas;
-- =====================================================================

create table if not exists rota_visitas (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  cliente_id    uuid not null references rota_clientes(id) on delete cascade,
  data          date not null,
  hora          time,                                   -- opcional
  duracao_min   integer,                                -- opcional (senão vale o do cliente ou o padrão)
  representadas uuid[] not null default '{}',           -- em nome de quais empresas é a visita (pode ser mais de uma)
  assunto       text not null default '',
  status        text not null default 'agendada' check (status in ('agendada','realizada','cancelada')),
  resultado     text not null default '',
  notas         text not null default '',
  ordem         integer,                                -- ordem do dia, depois de calcular a rota
  realizada_em  timestamptz,
  checkin_lat   double precision,                       -- GPS no momento de concluir (opcional)
  checkin_lng   double precision,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists rota_visitas_user_data_idx on rota_visitas(user_id, data);
create index if not exists rota_visitas_cliente_idx   on rota_visitas(cliente_id);

alter table rota_visitas enable row level security;
drop policy if exists rota_visitas_all on rota_visitas;
create policy rota_visitas_all on rota_visitas for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke all on rota_visitas from anon;
grant select, insert, update, delete on rota_visitas to authenticated;

-- a visita só pode apontar para um cliente da própria pessoa
create or replace function rota_visita_confere_dono() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from rota_clientes c where c.id = new.cliente_id and c.user_id = new.user_id) then
    raise exception 'cliente inválido';
  end if;
  return new;
end $$;
drop trigger if exists trg_rota_visita_dono on rota_visitas;
create trigger trg_rota_visita_dono before insert or update on rota_visitas
  for each row execute function rota_visita_confere_dono();

-- ---------- conferência (resultado esperado: 2 linhas "ok") ----------
select 'tabela rota_visitas' as item,
       case when to_regclass('public.rota_visitas') is not null then 'ok' else 'FALTOU' end as situacao
union all select 'gatilho de segurança',
       case when exists (select 1 from pg_trigger where tgname = 'trg_rota_visita_dono') then 'ok' else 'FALTOU' end;
