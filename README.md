# Servidor de e-mail no Coolify com Mailu

Projeto para subir uma stack de e-mail open source no Coolify usando Docker Compose. A base escolhida e o Mailu, que inclui SMTP, IMAP, webmail Roundcube, painel administrativo, antispam Rspamd, antivirus ClamAV, DKIM e suporte a SPF/DMARC.

> Observacao importante: um servidor de e-mail completo nao deve ser empacotado em um unico Dockerfile. No Coolify, use este repositorio como aplicacao Docker Compose ou Raw Compose. O `Dockerfile` existe apenas como auxiliar/documentacao caso o Coolify force a deteccao de Dockerfile.

## Componentes open source

- Mailu 2024.06: stack principal de e-mail em Docker, usando imagens publicas do GHCR.
- Postfix: SMTP.
- Dovecot: IMAP/POP3.
- Roundcube: webmail.
- Rspamd: antispam.
- ClamAV: antivirus via imagem `clamav/clamav-debian:1.4`.
- Redis e Unbound: suporte interno da stack.

## Pre-requisitos da VPS

- VPS com IP publico fixo.
- Porta 25 liberada pelo provedor. Muitos provedores bloqueiam SMTP de saida.
- Reverse DNS/PTR apontando para `mail.seudominio.com`.
- Coolify ja instalado.
- DNS do dominio sob seu controle.
- Nenhum outro servidor usando as portas `25`, `465`, `587`, `110`, `143`, `993`, `995`.

## Portas usadas

Portas publicas expostas diretamente no host:

- `25`: SMTP entre servidores.
- `465`: SMTPS.
- `587`: Submission para clientes autenticados.
- `110`: POP3 opcional.
- `143`: IMAP com STARTTLS.
- `993`: IMAPS.
- `995`: POP3S.

A interface web roda no container `front-mail` na porta interna `80` e deve ser publicada pelo dominio configurado no Coolify, por exemplo `https://mail.seudominio.com`.

No Coolify, mantenha `PORTS=25,80,443,110,995,143,993,587,465,4190` para que o Mailu habilite os listeners internos correspondentes. Tambem mantenha `ADMIN=true` para publicar o painel em `/admin`.

## Passo a passo no Coolify

1. Crie um novo projeto no Coolify.
2. Crie uma nova aplicacao a partir deste repositorio Git.
3. Selecione o build/deploy pack `Docker Compose`.
4. Se o Coolify oferecer `Raw Compose Deployment`, pode usar tambem. Para este caso, mantenha o servico `front-mail` associado ao dominio HTTP.
5. Configure o dominio do servico `front-mail` como `https://mail.seudominio.com`.
6. Na tela de variaveis de ambiente, preencha todas as variaveis obrigatorias:
   - `MAIL_DOMAIN=seudominio.com`
   - `MAIL_HOSTNAMES=mail.seudominio.com`
   - `INITIAL_ADMIN_ACCOUNT=admin`
   - `INITIAL_ADMIN_DOMAIN=seudominio.com`
   - `INITIAL_ADMIN_PW=<senha forte>`
   - `SECRET_KEY=<chave aleatoria forte>`
   - `ADMIN=true`
   - `API=false`
7. Mantenha `TLS_FLAVOR=cert` em VPS com Coolify, porque o proxy do Coolify normalmente ja ocupa as portas 80/443 do host.
8. Antes do primeiro deploy, coloque os certificados TLS em:
   - `./data/certs/cert.pem`
   - `./data/certs/key.pem`
9. Faca o deploy.
10. Acesse:
   - Admin: `https://mail.seudominio.com/admin`
   - Webmail: `https://mail.seudominio.com/webmail`

## Certificados TLS

Como o Coolify normalmente controla `80/443`, o Mailu nao deve tentar emitir certificado por HTTP-01 dentro da stack. Use uma destas opcoes:

- Recomendado: emitir certificado fora da stack com `acme.sh` ou `certbot` via DNS-01 e copiar/renovar `cert.pem` e `key.pem` em `./data/certs`.
- Alternativa: se a VPS nao usar o proxy do Coolify em `80/443`, adapte o compose para expor `80:80` e `443:443` e use `TLS_FLAVOR=letsencrypt`.

Os certificados precisam cobrir o hostname em `MAIL_HOSTNAMES`, por exemplo `mail.seudominio.com`.

## DNS necessario

Substitua `seudominio.com`, `mail.seudominio.com` e `IP_DA_VPS`.

```dns
mail.seudominio.com.  A      IP_DA_VPS
seudominio.com.       MX 10  mail.seudominio.com.
seudominio.com.       TXT    "v=spf1 mx -all"
_dmarc.seudominio.com TXT    "v=DMARC1; p=quarantine; rua=mailto:postmaster@seudominio.com"
```

Depois do primeiro deploy, gere/consulte o DKIM no painel admin do Mailu e publique o TXT indicado por ele.

Tambem configure o PTR/reverse DNS no painel do provedor da VPS:

```text
IP_DA_VPS -> mail.seudominio.com
```

## Criacao do primeiro dominio e usuarios

1. Entre em `https://mail.seudominio.com/admin`.
2. Faca login como `admin@seudominio.com`.
3. Crie ou confirme o dominio `seudominio.com`.
4. Confira a chave DKIM e publique o registro DNS.
5. Crie os usuarios finais.
6. Oriente usuarios a acessar `https://mail.seudominio.com/webmail`.

## Testes recomendados

No servidor:

```bash
docker compose ps
docker compose logs -f front-mail smtp-mail imap-mail admin-mail
```

De fora da VPS:

```bash
openssl s_client -connect mail.seudominio.com:993 -servername mail.seudominio.com
openssl s_client -starttls smtp -connect mail.seudominio.com:587 -servername mail.seudominio.com
```

Valide reputacao e DNS em ferramentas publicas como MXToolbox, Mail Tester ou equivalente.

Se o admin mostrar erro de DNS em `127.0.0.11`, confirme no Coolify que o deploy esta usando o compose atualizado. O Mailu precisa usar o resolver interno `resolver-mail` no IP de `RESOLVER_IPV4`, pois versoes recentes exigem DNSSEC.

## Operacao e backup

Faca backup de todo o diretorio `./data`, principalmente:

- `./data/mail`
- `./data/admin`
- `./data/dkim`
- `./data/certs`
- `./data/webmail`
- `./data/clamav`

Antes de atualizar `MAILU_VERSION`, leia as notas da versao do Mailu e faca backup.

## Fontes consultadas

- Mailu: https://mailu.io/2024.06/
- Mailu Docker Compose setup: https://mailu.io/2024.06/compose/setup.html
- Mailu configuration reference: https://mailu.io/2024.06/configuration.html
- Mailu DNS setup: https://mailu.io/2024.06/dns.html
- Coolify Docker Compose docs: https://coolify.io/docs/knowledge-base/docker/compose
