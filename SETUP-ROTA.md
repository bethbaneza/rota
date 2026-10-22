# Banheza Rota — Etapa 0 (base)

Esta etapa deixa pronto: o app em branco (entrar / criar conta / esqueci a senha) e a base no
banco de dados. **Nada do Assist muda** — só uma pequena regra no cadastro, que passa a ignorar
quem se cadastra pelo Rota.

## PASSO 1 — Backup rápido (2 minutos, só por segurança)

No Supabase do Assist (projeto "geracampo"):
1. **Table Editor → empresas → (⋯) → Export → CSV**. Guarde o arquivo.
2. Faça o mesmo com a tabela **perfis**.

(O plano gratuito do Supabase não tem backup automático para baixar, por isso fazemos esse manual.
A mudança é reversível — veja "Como desfazer" no começo do arquivo `supabase-rota-base.sql`.)

## PASSO 2 — Rodar o SQL

1. Supabase → **SQL Editor → New query**.
2. Abra `supabase-rota-base.sql` no Bloco de Notas, **Ctrl+A, Ctrl+C**, cole no editor e clique em **Run**.
3. No fim aparece uma tabela com 3 linhas. As três precisam dizer **ok**:
   - guarda no cadastro do Assist → ok
   - tabela rota_perfis → ok
   - gatilho do Rota → ok
4. Se aparecer a mensagem "estrutura inesperada", **nada foi alterado**: copie a mensagem e me envie.

## PASSO 3 — Conferir que o Assist continua normal

1. Entre no Assist (app.banheza.com.br) com o seu login e abra Clientes e Ordens de Serviço.
2. (Opcional, mais completo) Crie uma conta de teste pelo cadastro do Assist e confira que ela
   ganha uma empresa nova como antes.

## PASSO 4 — Liberar o endereço do Rota no login

Supabase → **Authentication → URL Configuration**:
- Em **Redirect URLs**, clique em **Add URL** e adicione `https://rota.banheza.com.br` (e também
  `https://rota.banheza.com.br/**`). **Não apague** as que já existem.
- Não troque o "Site URL" (é o do Assist).

## PASSO 5 — Publicar o app (depende da sua aprovação)

- Criar o repositório `rota` no GitHub e ligar o GitHub Pages.
- No Wix (ou onde o domínio é gerenciado), criar o endereço `rota.banheza.com.br` apontando para o GitHub Pages.
  Eu te passo os valores exatos quando chegar nessa hora.

## Teste do Rota depois de publicado

1. Abra o app, toque em **Criar conta**, preencha e entre.
2. Deve aparecer "Olá, <seu nome>." e a data de fim do teste grátis.
3. No SQL Editor do Supabase, confirme que **não** nasceu empresa nova no Assist:
   `select count(*) from empresas;` — o número não pode aumentar com o cadastro do Rota.

---

# Etapa 1 — Clientes, representadas e importação de planilha

## Rodar o SQL das tabelas

1. Supabase → **SQL Editor → New query**.
2. Abra `supabase-rota-clientes.sql`, **Ctrl+A, Ctrl+C**, cole e clique em **Run**.
3. No fim aparecem 3 linhas (rota_representadas, rota_clientes, rota_contatos). As três precisam dizer **ok**.

(Rode **depois** do `supabase-rota-base.sql`.)

## Como usar

- **Clientes → Novo:** cadastro completo (empresa, endereço pelo CEP, contatos/comprador, horários, representadas).
- **Mais → Representadas:** cadastre as empresas que você representa.
- **Mais → Importar planilha:** escolha o arquivo (CSV ou Excel). O app reconhece a planilha do Bling,
  liga as colunas sozinho, deixa de fora os **fornecedores** e mostra tudo para você conferir antes de gravar.
  Importar o mesmo arquivo de novo **não duplica** (o CNPJ/CPF identifica o cliente).

---

# Etapa 2 — Mapa, localização e rota do dia

## 1) Rodar o SQL
SQL Editor → cole `supabase-rota-etapa2.sql` → Run. As 3 linhas finais precisam dizer **ok**.

## 2) Chave do OpenRouteService (distâncias pelas ruas)
1. Crie a conta em `openrouteservice.org` e, no Dashboard, gere um token do tipo **Free**.
2. Supabase → **Edge Functions → Deploy new function** → nome `rota-ors` → cole o conteúdo de
   `supabase/functions/rota-ors/index.ts`. Deixe **"Verify JWT" LIGADO** (padrão).
3. **Edge Functions → Secrets → Add secret:** nome `ORS_API_KEY`, valor = o token. (Nunca no chat.)

Sem a chave, o app continua funcionando: calcula uma estimativa pela distância em linha reta e avisa na tela.

## 3) Usar
- **Mais → Minha casa e visitas:** endereço de saída/volta e tempo padrão de visita.
- **Clientes → Localizar agora:** converte os endereços em pontos no mapa (1 a 3 s por cliente).
  Pontos laranja = localização aproximada (pelo CEP); corrija o endereço no cadastro para ficar exato.
- **Clientes → Mapa:** todos os clientes no mapa, com filtro por representada.
- **Rota:** marque os clientes do dia, escolha a data e a hora de saída e toque em **Calcular melhor rota**.
  A rota mostra a ordem, o horário previsto de cada parada, a distância e o tempo; abre no Waze/Google Maps; **Salvar rota**
  guarda o dia e permite marcar cada visita como feita.

## Plano B sem chave (OSRM)
Se a chave do OpenRouteService não estiver configurada ou o serviço estiver fora do ar, o app usa o OSRM (serviço público e gratuito do OpenStreetMap, sem cadastro) para calcular distâncias e o traçado pelas ruas. Se nenhum dos dois responder, mostra uma estimativa pela distância em linha reta e avisa na tela.

---

# Etapa 3 — Agenda, painel e novo layout

## Rodar o SQL
SQL Editor → cole `supabase-rota-etapa3.sql` → Run. As 2 linhas finais precisam dizer **ok**.

## O que mudou
- **Início:** visitas de hoje, próximos 7 dias, atrasadas, as **próximas visitas**, as **últimas 5 visitas** e os clientes que passaram do intervalo de visita.
- **Agenda:** calendário do mês + lista do dia; abas Dia / Próximas / Realizadas; filtro por empresa representada. Cada visita pode ser em nome de **mais de uma empresa**.
- **Clientes:** só o cadastro (empresa, endereço, contatos, preferências) + histórico de visitas do cliente. No computador, a lista vira tabela larga.
- **Rota do dia:** parte das visitas agendadas do dia; clientes adicionados na hora viram visitas; **Aplicar horários na agenda** grava a ordem e o horário previsto; marcar **Visitado** conclui a visita.
- **Layout:** no computador usa a tela inteira, com menu lateral e formulários em colunas; no celular, barra de baixo.
