-- =====================================================================
-- Banheza Rota — ETAPA 4 (valor das vendas e comissão estimada)
-- Rode no SQL Editor do projeto Supabase do Assist, DEPOIS do supabase-rota-etapa3.sql.
-- É seguro rodar de novo.
--
-- Acrescenta em rota_visitas o campo "vendas": o valor vendido na visita (só dos produtos,
-- sem frete e instalação), guardado por empresa representada. Não é obrigatório:
-- visita sem venda fica com o campo vazio.
-- Exemplo do conteúdo:  {"<id da empresa A>": 1500.00, "<id da empresa B>": 320.50}
--
-- NÃO mexe em nada do Assist. As regras de segurança da tabela continuam as mesmas.
-- COMO DESFAZER:  alter table rota_visitas drop column if exists vendas;
-- =====================================================================

alter table rota_visitas add column if not exists vendas jsonb not null default '{}'::jsonb;

-- ---------- conferência (resultado esperado: 1 linha "ok") ----------
select 'rota_visitas.vendas' as item,
       case when exists (select 1 from information_schema.columns where table_name='rota_visitas' and column_name='vendas') then 'ok' else 'FALTOU' end as situacao;
