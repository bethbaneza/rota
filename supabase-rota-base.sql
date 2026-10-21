-- =====================================================================
-- Banheza Rota — BASE (Etapa 0)
-- Rode no SQL Editor do projeto Supabase do Assist (o "geracampo"), UMA vez.
-- É seguro rodar de novo: nada é duplicado nem sobrescrito.
--
-- O que faz:
--   1) Ensina o cadastro do Assist a IGNORAR quem se cadastra pelo app Rota
--      (senão cada representante ganharia, sem querer, uma "empresa" do Assist).
--   2) Cria a tabela rota_perfis (um registro por usuário do Rota) com
--      regras de segurança: cada pessoa só vê e edita o próprio perfil.
--   3) Cria o gatilho que preenche rota_perfis quando alguém se cadastra pelo Rota.
--
-- NÃO mexe em nenhuma tabela, tela ou dado do Assist.
--
-- COMO DESFAZER (se algum dia precisar):
--   - Passo 1: rode de novo apenas o bloco "create or replace function on_auth_user_created()"
--     do arquivo supabase-saas.sql do Assist (linhas 77 a 117) — volta ao original.
--   - Passos 2 e 3:  drop trigger if exists trg_rota_auth_user_created on auth.users;
--                    drop function if exists rota_on_auth_user_created();
--                    drop table if exists rota_perfis;
-- =====================================================================

-- ---------- 1. Cadastro do Assist ignora quem vem do Rota -------------
-- Em vez de reescrever a função inteira (e correr o risco de trocar algo que já
-- está em produção), lemos a definição ATUAL e só acrescentamos, logo depois do
-- "begin", a linha que sai sem fazer nada quando o app de origem é o Rota.
do $$
declare
  def text;
  guarda text := E'  -- Banheza Rota: quem se cadastra pelo app Rota não vira empresa do Assist\n'
                 || E'  if new.raw_user_meta_data->>''app'' = ''rota'' then return new; end if;\n';
  n int;
begin
  def := pg_get_functiondef('public.on_auth_user_created()'::regprocedure);
  if position('app'' = ''rota' in def) > 0 then
    raise notice 'Passo 1 já estava aplicado — nada a fazer.';
    return;
  end if;
  -- só segue se houver EXATAMENTE um "begin" sozinho numa linha (estrutura esperada)
  select count(*) into n from regexp_matches(def, E'\nbegin\r?\n', 'g');
  if n <> 1 then
    raise exception 'A função on_auth_user_created tem uma estrutura inesperada (% blocos begin). Nada foi alterado — me envie o resultado de: select pg_get_functiondef(''public.on_auth_user_created()''::regprocedure);', n;
  end if;
  def := regexp_replace(def, E'(\nbegin\r?\n)', E'\\1' || guarda);
  execute def;
  raise notice 'Passo 1 aplicado: o cadastro do Assist agora ignora usuários do Rota.';
end $$;

-- ---------- 2. Perfil de quem usa o Rota ------------------------------
create table if not exists rota_perfis (
  id         uuid primary key references auth.users(id) on delete cascade,
  nome       text not null default '',
  plano      text not null default 'trial',
  trial_ate  timestamptz not null default (now() + interval '30 days'),
  criado_em  timestamptz not null default now()
);

alter table rota_perfis enable row level security;

drop policy if exists rota_perfis_sel on rota_perfis;
create policy rota_perfis_sel on rota_perfis for select to authenticated
  using (id = auth.uid());

-- só o nome pode ser editado pela própria pessoa (plano e teste são controlados pelo sistema)
drop policy if exists rota_perfis_upd on rota_perfis;
create policy rota_perfis_upd on rota_perfis for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke all on rota_perfis from anon;
revoke insert, update, delete on rota_perfis from authenticated;
grant update (nome) on rota_perfis to authenticated;
grant select on rota_perfis to authenticated;

-- ---------- 3. Gatilho: cadastro pelo Rota -> cria o perfil -----------
create or replace function rota_on_auth_user_created() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if new.raw_user_meta_data->>'app' = 'rota' then
    insert into rota_perfis(id, nome)
      values (new.id,
              coalesce(nullif(trim(new.raw_user_meta_data->>'nome'), ''), split_part(new.email, '@', 1)))
      on conflict (id) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists trg_rota_auth_user_created on auth.users;
create trigger trg_rota_auth_user_created after insert on auth.users
  for each row execute function rota_on_auth_user_created();

-- ---------- Conferência (resultado esperado: 3 linhas "ok") -----------
select 'guarda no cadastro do Assist' as item,
       case when position('app'' = ''rota' in pg_get_functiondef('public.on_auth_user_created()'::regprocedure)) > 0
            then 'ok' else 'FALTOU' end as situacao
union all
select 'tabela rota_perfis',
       case when to_regclass('public.rota_perfis') is not null then 'ok' else 'FALTOU' end
union all
select 'gatilho do Rota',
       case when exists (select 1 from pg_trigger where tgname = 'trg_rota_auth_user_created') then 'ok' else 'FALTOU' end;
