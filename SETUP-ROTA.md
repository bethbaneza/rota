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
