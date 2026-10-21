-- =====================================================================
-- Banheza Rota — CLIENTES (Etapa 1)
-- Rode no SQL Editor do projeto Supabase do Assist, DEPOIS do supabase-rota-base.sql.
-- É seguro rodar de novo: nada é apagado nem duplicado.
--
-- Cria 3 tabelas, todas com regras de segurança "cada pessoa só vê o que é dela":
--   rota_representadas  — as empresas que o representante atende
--   rota_clientes       — a carteira de clientes (empresa, endereço, horários, vínculo com as representadas)
--   rota_contatos       — as pessoas de cada cliente (comprador, financeiro...)
--
-- NÃO mexe em nenhuma tabela do Assist.
--
-- COMO DESFAZER:  drop table if exists rota_contatos, rota_clientes, rota_representadas;
-- =====================================================================

create table if not exists rota_representadas (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome       text not null,
  comissao   numeric(5,2),
  obs        text not null default '',
  criado_em  timestamptz not null default now()
);

create table if not exists rota_clientes (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid() references auth.users(id) on delete cascade,
  razao            text not null,
  fantasia         text not null default '',
  doc              text not null default '',      -- CNPJ/CPF só com números
  ie               text not null default '',
  segmento         text not null default '',
  cep              text not null default '',
  endereco         text not null default '',
  numero           text not null default '',
  complemento      text not null default '',
  bairro           text not null default '',
  cidade           text not null default '',
  uf               text not null default '',
  lat              double precision,              -- preenchidos na Etapa 2 (ponto no mapa)
  lng              double precision,
  tel              text not null default '',
  celular          text not null default '',
  email            text not null default '',
  site             text not null default '',
  obs              text not null default '',
  horario          text not null default '',      -- ex.: "seg a sex, 8h às 17h"
  tempo_visita_min integer,
  freq_dias        integer,                        -- a cada quantos dias visitar
  representadas    uuid[] not null default '{}',   -- quais representadas atendem este cliente
  origem           text not null default 'manual', -- manual | bling | planilha
  id_externo       text not null default '',
  ativo            boolean not null default true,
  criado_em        timestamptz not null default now(),
  atualizado_em    timestamptz not null default now()
);
-- um mesmo CNPJ/CPF não pode aparecer duas vezes na carteira da mesma pessoa
create unique index if not exists rota_clientes_doc_uk on rota_clientes(user_id, doc) where doc <> '';
create index if not exists rota_clientes_user_idx on rota_clientes(user_id);

create table if not exists rota_contatos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  cliente_id  uuid not null references rota_clientes(id) on delete cascade,
  nome        text not null default '',
  cargo       text not null default '',
  tel         text not null default '',
  email       text not null default '',
  principal   boolean not null default false,
  criado_em   timestamptz not null default now()
);
create index if not exists rota_contatos_cli_idx on rota_contatos(cliente_id);
create index if not exists rota_contatos_user_idx on rota_contatos(user_id);

-- ---------- segurança: cada pessoa só enxerga e altera o que é dela ----------
do $$
declare t text;
begin
  foreach t in array array['rota_representadas','rota_clientes','rota_contatos'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t || '_all', t);
    execute format('create policy %I on %I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())', t || '_all', t);
    execute format('revoke all on %I from anon', t);
    execute format('grant select, insert, update, delete on %I to authenticated', t);
  end loop;
end $$;

-- o contato só pode apontar para um cliente da própria pessoa
create or replace function rota_contato_confere_dono() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from rota_clientes c where c.id = new.cliente_id and c.user_id = new.user_id) then
    raise exception 'cliente inválido';
  end if;
  return new;
end $$;
drop trigger if exists trg_rota_contato_dono on rota_contatos;
create trigger trg_rota_contato_dono before insert or update on rota_contatos
  for each row execute function rota_contato_confere_dono();

-- ---------- conferência (resultado esperado: 3 linhas "ok") ----------
select 'rota_representadas' as tabela, case when to_regclass('public.rota_representadas') is not null then 'ok' else 'FALTOU' end as situacao
union all select 'rota_clientes',  case when to_regclass('public.rota_clientes')  is not null then 'ok' else 'FALTOU' end
union all select 'rota_contatos',  case when to_regclass('public.rota_contatos')  is not null then 'ok' else 'FALTOU' end;
