# Servidor de e-mail no Coolify com Mailu

Projeto para subir uma stack de e-mail open source no Coolify usando Docker Compose. A base escolhida e o Mailu 2024.06, que inclui SMTP, IMAP, webmail Roundcube, painel administrativo, antispam Rspamd, antivirus ClamAV, DKIM, SPF e DMARC.

> Um servidor de e-mail completo nao deve ser empacotado em um unico container. No Coolify, use este repositorio como aplicacao Docker Compose ou Raw Compose. O `Dockerfile` existe apenas como auxiliar caso o Coolify force deteccao de Dockerfile.

## Estado validado

Ambiente validado em producao com:

- Dominio: `dominus-ai.net.br`
- Hostname publico: `mail.dominus-ai.net.br`
- Painel admin em `https://mail.dominus-ai.net.br/admin/`
- Webmail em `https://mail.dominus-ai.net.br/webmail/`
- Login inicial e troca de senha no primeiro acesso funcionando.
- Criacao de novos usuarios funcionando.
- Envio e recebimento de e-mails funcionando.
- SMTP Submission `587`, SMTPS `465` e IMAPS `993` com certificado valido.

## Componentes

- Mailu 2024.06: stack principal.
- Postfix: SMTP.
- Dovecot: IMAP/POP3/LMTP/Sieve.
- Roundcube: webmail.
- Rspamd: antispam.
- ClamAV: antivirus.
- Redis: suporte interno.
- Unbound: resolver DNS interno com DNSSEC.

## Pre-requisitos

- VPS com IP publico fixo.
- Coolify instalado.
- DNS do dominio sob seu controle.
- Porta `25` liberada pelo provedor.
- Portas livres no host: `25`, `465`, `587`, `110`, `143`, `993`, `995`.
- PTR/reverse DNS apontando o IP da VPS para `mail.seudominio.com`.
- Certificado TLS para o hostname de e-mail, por exemplo `mail.seudominio.com`.

## Portas

Portas publicas publicadas pelo container `front-mail`:

- `25`: SMTP entre servidores.
- `465`: SMTPS.
- `587`: SMTP Submission para clientes autenticados.
- `110`: POP3 opcional.
- `143`: IMAP com STARTTLS.
- `993`: IMAPS.
- `995`: POP3S.

A interface web roda internamente no `front-mail:80` e deve ser publicada pelo proxy do Coolify. No Coolify, configure o dominio do servico `front-mail` com porta interna explicita:

```text
https://mail.seudominio.com:80
```

Nao configure dominio para `admin-mail`, `webmail-mail`, `imap-mail`, `smtp-mail`, `antispam-mail`, `antivirus-mail`, `fetchmail-mail`, `redis-mail` ou `resolver-mail`.

## Variaveis obrigatorias

Exemplo para `dominus-ai.net.br`:

```env
MAILU_VERSION=2024.06
MAIL_DOMAIN=dominus-ai.net.br
MAIL_HOSTNAMES=mail.dominus-ai.net.br
POSTMASTER=postmaster
SITENAME=Mail
WEBSITE=https://mail.dominus-ai.net.br

SECRET_KEY=<chave-aleatoria-forte>
INITIAL_ADMIN_ACCOUNT=admin
INITIAL_ADMIN_DOMAIN=dominus-ai.net.br
INITIAL_ADMIN_PW=<senha-forte>
INITIAL_ADMIN_MODE=ifmissing

BIND_ADDRESS4=0.0.0.0
MAILU_SUBNET=192.168.203.0/24
RESOLVER_IPV4=192.168.203.254
PORTS=25,80,443,110,995,143,993,587,465,4190

ADMIN_ADDRESS=admin-mail-internal
ANTISPAM_ADDRESS=antispam-mail-internal
ANTIVIRUS_ADDRESS=antivirus-mail-internal
FRONT_ADDRESS=front-mail-internal
IMAP_ADDRESS=imap-mail-internal
REDIS_ADDRESS=redis-mail-internal
SMTP_ADDRESS=smtp-mail-internal
WEBMAIL_ADDRESS=webmail-mail-internal

TLS_FLAVOR=mail

ADMIN=true
API=false
WEBMAIL=roundcube
WEB_ADMIN=/admin
WEB_WEBMAIL=/webmail
WEB_API=/api
WEBROOT_REDIRECT=/webmail
REAL_IP_HEADER=X-Forwarded-For
REAL_IP_FROM=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16

MESSAGE_SIZE_LIMIT=50000000
MESSAGE_RATELIMIT=200/day
DEFAULT_QUOTA=1073741824
DEFAULT_SPAM_THRESHOLD=80
AUTH_RATELIMIT_IP=5/hour
AUTH_RATELIMIT_USER=50/day
AUTH_RATELIMIT_EXEMPTION=

ANTIVIRUS=clamav
FETCHMAIL_ENABLED=True
FETCHMAIL_DELAY=600
LOG_LEVEL=WARNING
WEBDAV=none
```

### Por que usar aliases `*-mail-internal`

O Coolify pode conectar os containers a uma rede propria alem da rede default do Compose. Se o Mailu resolver `imap-mail` pela rede do Coolify, o Dovecot pode ver conexoes vindas de uma subnet nao confiavel e recusar login IMAP.

Por isso, os `*_ADDRESS` devem apontar para aliases exclusivos da rede Mailu:

```env
IMAP_ADDRESS=imap-mail-internal
ADMIN_ADDRESS=admin-mail-internal
SMTP_ADDRESS=smtp-mail-internal
```

Apos o deploy, estes aliases devem resolver para a subnet de `MAILU_SUBNET`, por exemplo `192.168.203.x`.

## Passo a passo no Coolify

1. Crie um novo projeto.
2. Crie uma aplicacao a partir deste repositorio Git.
3. Selecione `Docker Compose` ou `Raw Compose Deployment`.
4. Configure somente o dominio do servico `front-mail`:

```text
https://mail.seudominio.com:80
```

5. Deixe os demais servicos sem dominio publico.
6. Preencha as variaveis de ambiente.
7. Garanta que `TLS_FLAVOR=mail`.
8. Coloque `cert.pem` e `key.pem` no volume `./data/certs`.
9. Faca deploy/recreate completo.
10. Acesse:

```text
https://mail.seudominio.com/admin/
https://mail.seudominio.com/webmail/
```

## Certificados TLS

Em VPS com Coolify, o proxy geralmente controla `80/443`. Portanto o Mailu nao deve tentar emitir certificado por HTTP-01 dentro da stack nem forcar HTTPS na web interna.

Use:

```env
TLS_FLAVOR=mail
```

Com esse modo:

- A web roda em HTTP interno atras do proxy HTTPS do Coolify.
- SMTP/IMAP continuam usando os arquivos em `/certs`.

Arquivos esperados:

```text
./data/certs/cert.pem
./data/certs/key.pem
```

### Exemplo com acme.sh e DNS-01 manual

```bash
~/.acme.sh/acme.sh --issue \
  --dns \
  -d mail.seudominio.com \
  --force \
  --yes-I-know-dns-manual-mode-enough-go-ahead-please
```

Crie no DNS o TXT informado pelo acme.sh, por exemplo:

```dns
_acme-challenge.mail.seudominio.com TXT "VALOR_GERADO"
```

Depois valide e renove:

```bash
dig TXT _acme-challenge.mail.seudominio.com +short

~/.acme.sh/acme.sh --renew \
  -d mail.seudominio.com \
  --yes-I-know-dns-manual-mode-enough-go-ahead-please
```

Instale os arquivos no volume da aplicacao:

```bash
~/.acme.sh/acme.sh --install-cert -d mail.seudominio.com --ecc \
  --key-file /data/coolify/applications/APP_ID/data/certs/key.pem \
  --fullchain-file /data/coolify/applications/APP_ID/data/certs/cert.pem
```

Valide:

```bash
openssl x509 -in /data/coolify/applications/APP_ID/data/certs/cert.pem -noout -subject -issuer -dates
```

## DNS

Substitua `seudominio.com`, `mail.seudominio.com` e `IP_DA_VPS`.

```dns
mail.seudominio.com.        A      IP_DA_VPS
seudominio.com.             MX 10  mail.seudominio.com.
seudominio.com.             TXT    "v=spf1 mx ~all"
_dmarc.seudominio.com.      TXT    "v=DMARC1; p=none; rua=mailto:dmarc@seudominio.com"
```

Apos o primeiro deploy, acesse o admin do Mailu, consulte o DKIM do dominio e publique o TXT indicado.

Configure tambem o PTR/reverse DNS no provedor da VPS:

```text
IP_DA_VPS -> mail.seudominio.com
```

## Primeiro acesso e usuarios

1. Acesse `https://mail.seudominio.com/admin/`.
2. Entre com `admin@seudominio.com` e a senha de `INITIAL_ADMIN_PW`.
3. Confirme ou crie o dominio.
4. Publique o DKIM no DNS.
5. Crie usuarios finais.
6. Se marcar troca de senha no primeiro login, o usuario deve acessar o webmail e alterar a senha quando solicitado.

Para redefinir senha via CLI:

```bash
ADMIN=$(docker ps --format '{{.Names}}' | grep admin-mail | head -n 1)
docker exec "$ADMIN" flask mailu password usuario seudominio.com 'NOVA_SENHA_FORTE'
```

## Testes de validacao

### Web

```bash
curl -IL https://mail.seudominio.com/admin/
curl -IL https://mail.seudominio.com/webmail/
```

O esperado e chegar em `200` ou em redirect normal para login, sem loop 301.

### Certificado e IMAP

```bash
openssl s_client -connect mail.seudominio.com:993 -servername mail.seudominio.com
```

Teste login IMAP:

```bash
openssl s_client -connect mail.seudominio.com:993 -servername mail.seudominio.com -quiet
```

Dentro do prompt:

```text
a login usuario@seudominio.com SENHA
a logout
```

O esperado e `a OK`.

### SMTP Submission

```bash
echo QUIT | openssl s_client -starttls smtp -connect mail.seudominio.com:587 -servername mail.seudominio.com
```

O esperado e certificado valido e `Verify return code: 0 (ok)`.

### Aliases internos

```bash
IMAP=$(docker ps --format '{{.Names}}' | grep imap-mail | head -n 1)

docker exec "$IMAP" getent hosts imap-mail-internal
docker exec "$IMAP" getent hosts admin-mail-internal
```

O esperado e resolver para `192.168.203.x`, nao para a rede adicional do Coolify.

### Auth interno do Mailu

```bash
docker exec "$IMAP" curl -i \
  -H 'Client-Ip: 192.168.203.4' \
  -H 'Client-Port: 12345' \
  -H 'Auth-Protocol: imap' \
  -H 'Auth-Method: plain' \
  -H 'Auth-User: usuario@seudominio.com' \
  -H 'Auth-Pass: SENHA' \
  -H 'Auth-Port: 993' \
  http://admin-mail-internal:8080/internal/auth/email
```

O esperado:

```text
Auth-Status: OK
Auth-Server: 192.168.203.x
Auth-Port: 143
```

## Troubleshooting

### Coolify pede dominio para todos os servicos

Configure dominio apenas em `front-mail`:

```text
front-mail = https://mail.seudominio.com:80
```

Deixe os demais sem dominio publico.

### Pull access denied para `mailu/rspamd`

Use imagens do GHCR:

```text
ghcr.io/mailu/rspamd:2024.06
```

Este compose ja usa o registry correto.

### Erro DNS resolver `127.0.0.11`

O Mailu precisa usar o resolver interno `resolver-mail` no IP `RESOLVER_IPV4`. Confirme:

```env
MAILU_SUBNET=192.168.203.0/24
RESOLVER_IPV4=192.168.203.254
```

### ClamAV nao resolve `database.clamav.net`

Normalmente e o mesmo problema de DNS interno. Confirme que o compose atualizado foi redeployado e que o antivirus usa o DNS `192.168.203.254`.

### Loop 301 em `/admin/` ou `/webmail/`

Use:

```env
TLS_FLAVOR=mail
```

Nao use `TLS_FLAVOR=cert` atras do proxy HTTPS do Coolify, pois o Mailu redireciona HTTP interno para HTTPS e cria loop.

### Gateway Timeout no admin

No dominio do Coolify, informe a porta interna:

```text
https://mail.seudominio.com:80
```

Se `curl` no servidor retorna `302`/`200`, mas o navegador continua em timeout, teste com um cache buster:

```text
https://mail.seudominio.com/admin/?t=20260627
```

Se funcionar com query string, o problema esta no estado local do navegador ou em cache de protocolo, nao no Mailu. Limpe os dados do site para o dominio, feche abas abertas do webmail/admin e teste novamente em janela anonima. Em Chrome/Edge, tambem pode ajudar limpar o cache HTTP/3/QUIC ou desativar temporariamente QUIC em `chrome://flags/#enable-quic`, especialmente quando a resposta contem `alt-svc: h3`.

### Webmail em loop em `/webmail/sso.php`

Primeiro teste IMAP direto. Enquanto IMAP nao autenticar, o webmail continuara em loop:

```bash
openssl s_client -connect mail.seudominio.com:993 -servername mail.seudominio.com -quiet
```

Se o auth interno retornar `Auth-Server` em `10.x.x.x`, os `*_ADDRESS` estao resolvendo pela rede do Coolify. Corrija para aliases `*-mail-internal` e redeploy.

### Usuario existe mas senha nao funciona

Se o usuario ja existia, `INITIAL_ADMIN_MODE=ifmissing` nao atualiza senha. Redefina pelo admin ou via CLI:

```bash
docker exec "$ADMIN" flask mailu password usuario seudominio.com 'NOVA_SENHA_FORTE'
```

### Rate limit durante diagnostico

Se um loop gerou muitas tentativas, use temporariamente:

```env
AUTH_RATELIMIT_EXEMPTION=10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,SEU_IP/32
```

Nao use `0.0.0.0/0` permanentemente em producao.

## Operacao e backup

Faca backup de todo o diretorio `./data`, principalmente:

- `./data/mail`
- `./data/admin`
- `./data/dkim`
- `./data/certs`
- `./data/webmail`
- `./data/clamav`
- `./data/redis`
- `./data/filter`
- `./data/mailqueue`

Antes de atualizar `MAILU_VERSION`, leia as notas da versao do Mailu e faca backup completo.

## Checklist para novo ambiente

1. Confirmar porta `25` liberada.
2. Configurar DNS `A`, `MX`, `SPF`, `DMARC`.
3. Configurar PTR/reverse DNS.
4. Gerar certificado para `mail.seudominio.com`.
5. Preencher variaveis no Coolify.
6. Configurar dominio apenas em `front-mail` com `:80`.
7. Fazer deploy/recreate completo.
8. Validar aliases internos `*-mail-internal`.
9. Validar IMAPS `993`.
10. Validar SMTP `587`.
11. Criar usuario.
12. Testar envio e recebimento.
13. Publicar DKIM.
14. Configurar rotina de backup.

## Fontes

- Mailu: https://mailu.io/2024.06/
- Mailu Docker Compose setup: https://mailu.io/2024.06/compose/setup.html
- Mailu configuration reference: https://mailu.io/2024.06/configuration.html
- Mailu DNS setup: https://mailu.io/2024.06/dns.html
- Coolify Docker Compose docs: https://coolify.io/docs/knowledge-base/docker/compose
