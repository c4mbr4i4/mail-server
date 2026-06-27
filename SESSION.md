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
- TLS de producao atras do Coolify: `TLS_FLAVOR=mail`, com `cert.pem` e `key.pem` em `./data/certs` para SMTP/IMAP e web HTTP interna atras do proxy HTTPS do Coolify.

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

## Correcao de deploy em 2026-06-25

- Erro reportado no Coolify: `pull access denied for mailu/rspamd`.
- Corrigidas imagens Mailu para usar o registry oficial atual da release: `ghcr.io/mailu/*`.
- Ajustado webmail para `ghcr.io/mailu/webmail:${MAILU_VERSION:-2024.06}`, mantendo `WEBMAIL=roundcube`.
- Ajustado antivirus para `clamav/clamav-debian:1.4`, conforme template oficial Mailu 2024.06.
- Volume do antivirus alterado para `./data/clamav:/var/lib/clamav`.

## Correcao DNS em 2026-06-25

- Erro reportado: admin tentando usar DNS `127.0.0.11` e antivirus sem resolver `database.clamav.net`.
- Criado anchor `x-mailu-dns` para aplicar `RESOLVER_IPV4` em todos os servicos que precisam resolver nomes externos.
- Adicionado `resolver-mail` em `depends_on` desses servicos.
- Adicionada rede `clamav` e conectados `antispam-mail` e `antivirus-mail`, mantendo ambos tambem na rede `default` para acessar o resolver interno.

## Correcao SMTP submission em 2026-06-26

- Porta `587` estava publicada no Docker, mas nao entregava banner SMTP/STARTTLS.
- Adicionada variavel `PORTS=25,80,443,110,995,143,993,587,465,4190`, usada pelo Mailu para ativar listeners internos como submission `587` e submissions `465`.

## Correcao admin em 2026-06-26

- Adicionados defaults `ADMIN=true` e `API=false` no compose e no `.env.example`.
- O painel admin deve ser acessado via `front-mail` em `/admin`; `admin-mail` continua sem dominio publico.

## Correcao proxy Coolify em 2026-06-26

- Admin respondeu internamente em `admin-mail:8080`, mas `https://mail.dominus-ai.net.br/admin` retornou Gateway Timeout.
- Diagnostico revisado: como o `front-mail` publica varias portas, o Coolify pode inferir a porta HTTP errada se o dominio nao indicar a porta interna.
- Removida rede externa `coolify`; a documentacao do Coolify informa que o proxy e adicionado a rede da stack.
- O dominio do servico `front-mail` deve ser configurado como `https://mail.dominus-ai.net.br:80` para rotear para a porta interna HTTP correta.

## Correcao loop HTTPS em 2026-06-26

- `curl -IL` em `/admin/` e `/webmail/` retornou loop 301 para a mesma URL HTTPS.
- Causa: `TLS_FLAVOR=cert` faz o Mailu redirecionar HTTP interno para HTTPS, mas o Coolify ja termina HTTPS e encaminha HTTP para `front-mail:80`.
- Alterado default para `TLS_FLAVOR=mail`, mantendo TLS nos protocolos SMTP/IMAP com certificados em `/certs` e deixando a web em HTTP interno atras do proxy do Coolify.

## Ajuste SSO webmail em 2026-06-26

- Webmail reportado em loop de redirect no navegador, embora `curl -IL` chegue ao login SSO com HTTP 200.
- Adicionados defaults `REAL_IP_HEADER=X-Forwarded-For` e `REAL_IP_FROM=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16`, conforme recomendacao do Mailu para uso atras de reverse proxy.
- Orientacao operacional: somente `front-mail` deve ter dominio publico no Coolify; `webmail-mail` e `admin-mail` devem ficar internos.

## Diagnostico auth webmail em 2026-06-26

- Logs mostraram loop em `/webmail/sso.php` junto de `imap-login ... AUTHENTICATIONFAILED` para `admin@dominus-ai.net.br`.
- Conclusao: o Roundcube/SSO esta acessivel, mas o login IMAP do usuario falha.
- Causa provavel: `INITIAL_ADMIN_MODE=ifmissing` nao atualiza senha de usuario ja existente; se `INITIAL_ADMIN_PW` mudou apos o primeiro deploy, a senha real do usuario permanece a antiga.
- Correcao: redefinir a senha do usuario no painel admin ou executar `flask mailu password admin dominus-ai.net.br 'NOVA_SENHA_FORTE'` no container `admin-mail`.

## Diagnostico auth IMAP em 2026-06-27

- `doveadm auth test` dentro do `imap-mail` falhou para usuarios ativos com IMAP habilitado.
- `SECRET_KEY` foi confirmado igual entre `admin-mail`, `imap-mail` e `front-mail`.
- Como o loop do webmail gerou muitas tentativas, o limitador `AUTH_RATELIMIT_USER=50/day` pode estar mantendo a recusa mesmo apos reset de senha.
- Adicionada variavel `AUTH_RATELIMIT_EXEMPTION` ao compose para permitir isentar redes internas/clientes durante diagnostico.
- Teste direto em `/internal/auth/email` retornou `Auth-Status: OK`, confirmando que senha e admin backend estavam corretos.
- O backend retornou `Auth-Server: 10.0.2.9`, IP da rede adicional do Coolify, enquanto o Dovecot confia apenas em `MAILU_SUBNET=192.168.203.0/24`.
- Causa raiz provavel: nomes como `imap-mail` resolvendo pela rede do Coolify em vez da rede interna Mailu, fazendo o proxy IMAP chegar de uma subnet nao confiavel.
- Ajuste aplicado: aliases internos `*-mail-internal` na rede default do Compose e defaults `*_ADDRESS` apontando para esses aliases.

## Validacao final em 2026-06-27

- Aliases internos passaram a resolver para `192.168.203.x`.
- `/internal/auth/email` passou a retornar `Auth-Server: 192.168.203.x`.
- Webmail funcionou.
- Usuario conseguiu alterar senha no primeiro login.
- Criacao de novo usuario validada.
- Envio e recebimento de e-mails validados.
- README reescrito como runbook para novos ambientes.

## Gateway Timeout no navegador em 2026-06-27

- Usuario reportou novo Gateway Timeout em `https://mail.dominus-ai.net.br/admin/`.
- Testes por `curl` no servidor retornaram `302` esperado para `/sso/login` e `200` na tela de login, indicando Mailu, front-mail e proxy respondendo.
- Logs do `front-mail` confirmaram requests chegando e sendo respondidos.
- A URL `https://mail.dominus-ai.net.br/admin/?t=20260627` funcionou no navegador.
- Conclusao: problema de estado/cache do navegador, possivelmente relacionado a redirects antigos ou cache HTTP/3/QUIC indicado pelo header `alt-svc: h3`.
- Documentado no README o uso de cache buster, limpeza de dados do site e teste/desativacao temporaria de QUIC.

## Pendencias recorrentes para novos ambientes

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

Para novos ambientes, seguir o checklist do `README.md`, validar aliases internos `*-mail-internal` e testar IMAP/SMTP antes de liberar usuarios finais.
