-- =====================================================================
-- Banheza Rota — ETAPA 2 (mapa e rota do dia)
-- Rode no SQL Editor do projeto Supabase do Assist, DEPOIS dos outros dois arquivos do Rota.
-- É seguro rodar de novo.
--
-- O que faz:
--   1) rota_perfis ganha o endereço de casa (ponto de saída/volta) e o tempo padrão de visita;
--   2) rota_clientes ganha "geo_status" (como o ponto no mapa foi encontrado);
--   3) cria rota_rotas, onde ficam as rotas calculadas e o que já foi visitado.
--
-- NÃO mexe em nada do Assist.
-- COMO DESFAZER:  drop table if exists rota_rotas;
--   (as colunas novas podem ficar; não atrapalham)
-- =====================================================================

-- 1) endereço de casa e tempo padrão de visita
alter table rota_perfis add column if not exists casa_cep    text not null default '';
alter table rota_perfis add column if not exists casa_endereco text not null default '';
alter table rota_perfis add column if not exists casa_numero text not null default '';
alter table rota_perfis add column if not exists casa_bairro text not null default '';
alter table rota_perfis add column if not exists casa_cidade text not null default '';
alter table rota_perfis add column if not exists casa_uf     text not null default '';
alter table rota_perfis add column if not exists casa_lat    double precision;
alter table rota_perfis add column if not exists casa_lng    double precision;
alter table rota_perfis add column if not exists visita_padrao_min integer not null default 45;

-- a pessoa pode editar só estes campos do próprio perfil (plano e teste continuam bloqueados)
grant update (nome, casa_cep, casa_endereco, casa_numero, casa_bairro, casa_cidade, casa_uf,
              casa_lat, casa_lng, visita_padrao_min) on rota_perfis to authenticated;

-- 2) como o ponto do cliente no mapa foi achado: pendente | numero | rua | cep | cidade | falhou
alter table rota_clientes add column if not exists geo_status text not null default 'pendente';

-- 3) rotas calculadas
create table if not exists rota_rotas (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data      date not null,
  titulo    text not null default '',
  saida     jsonb not null default '{}'::jsonb,     -- {endereco, lat, lng, volta}
  paradas   jsonb not null default '[]'::jsonb,     -- [{cliente_id, ordem, chegada, dur, visitado, hora}]
  total_km  numeric(8,1),
  total_min integer,
  calculo   text not null default 'estimativa',     -- ruas | estimativa
  criado_em timestamptz not null default now()
);
create index if not exists rota_rotas_user_idx on rota_rotas(user_id, data desc);

alter table rota_rotas enable row level security;
drop policy if exists rota_rotas_all on rota_rotas;
create policy rota_rotas_all on rota_rotas for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke all on rota_rotas from anon;
grant select, insert, update, delete on rota_rotas to authenticated;

-- ---------- conferência (resultado esperado: 3 linhas "ok") ----------
select 'perfil: endereço de casa' as item,
       case when exists (select 1 from information_schema.columns where table_name='rota_perfis' and column_name='casa_lat') then 'ok' else 'FALTOU' end as situacao
union all select 'clientes: geo_status',
       case when exists (select 1 from information_schema.columns where table_name='rota_clientes' and column_name='geo_status') then 'ok' else 'FALTOU' end
union all select 'tabela rota_rotas',
       case when to_regclass('public.rota_rotas') is not null then 'ok' else 'FALTOU' end;
