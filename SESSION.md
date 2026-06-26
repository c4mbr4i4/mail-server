# Sessao do projeto

Data: 2026-06-23

## Objetivo

Criar um projeto para subir um servico de e-mail em uma VPS com Coolify, incluindo SMTP, administracao web e webmail de usuarios, usando apenas solucoes open source bem avaliadas.

## Decisoes tomadas

- Base escolhida: Mailu 2024.06.
- Motivo: stack open source em Docker, com SMTP/IMAP, administracao web, webmail, antispam, antivirus, DKIM, SPF/DMARC e componentes FOSS.
- Deploy recomendado no Coolify: Docker Compose/Raw Compose.
- O `Dockerfile` foi mantido apenas como auxiliar/documentacao, porque um servidor de e-mail completo e multi-servico nao deve ser colocado em um unico container.
- Como Coolify geralmente ocupa `80/443`, a web do Mailu deve ser publicada pelo proxy do Coolify e as portas de e-mail devem ser expostas diretamente pelo compose.
- TLS de producao: `TLS_FLAVOR=cert`, com `cert.pem` e `key.pem` em `./data/certs`.

## Arquivos criados

- `docker-compose.yml`: stack Mailu para Coolify.
- `.env.example`: variaveis de referencia para preenchimento no Coolify.
- `Dockerfile`: helper/documentacao para evitar ambiguidade de deteccao.
- `README.md`: passo a passo de deploy, DNS, TLS, testes e operacao.
- `SESSION.md`: continuidade da sessao.

## Validacao realizada

- `rg -n "[^\\x00-\\x7F]" README.md SESSION.md docker-compose.yml .env.example Dockerfile`: sem caracteres nao ASCII.
- `docker-compose --env-file .env.example config`: compose validado com sucesso.
- Observacao: o Docker local exibiu aviso `Error loading config file: open C:\Users\acamb\.docker\config.json: Access is denied`, mas o comando retornou codigo 0 e gerou a configuracao normalizada.

## Atualizacao em 2026-06-25

- Renomeados os servicos do `docker-compose.yml` com sufixo `-mail` para evitar conflito com outros servicos no mesmo ambiente.
- Nomes atuais: `front-mail`, `resolver-mail`, `redis-mail`, `admin-mail`, `imap-mail`, `smtp-mail`, `antispam-mail`, `antivirus-mail`, `webmail-mail`, `fetchmail-mail`.
- Adicionadas variaveis `*_ADDRESS` no Compose e em `.env.example` para que os containers Mailu descubram os novos nomes DNS internos.

## Pendencias para deploy real

- Definir dominio final.
- Confirmar IP publico da VPS.
- Confirmar se a porta 25 esta liberada pelo provedor.
- Configurar PTR/reverse DNS para o hostname de e-mail.
- Gerar certificados TLS para `MAIL_HOSTNAMES` via DNS-01 ou processo externo.
- Preencher segredos fortes no Coolify:
  - `SECRET_KEY`
  - `INITIAL_ADMIN_PW`
- Publicar DKIM apos o primeiro deploy.

## Proximo passo sugerido

Adaptar os exemplos de dominio (`example.com`/`mail.example.com`) para o dominio real e validar o compose no servidor Coolify.
