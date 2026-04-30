# Página de Aceite — Contrato Legacy

Página HTML estática para aceite eletrônico do **Contrato de Prestação de Serviços Legacy The Legend**, com fluxo de verificação de identidade, captura de log técnico-jurídico e gravação no Supabase.

---

## 🎯 Fluxo

1. **CRM gera URL** com query params do contratante (preenchidos pelo vendedor).
2. Página abre **popup de identidade** (`"Você é X?"`) **antes** de qualquer conteúdo, evitando aceite por terceiro.
3. Cliente lê o contrato (link "nosso contrato de trabalho" abre modal com as 41 cláusulas) e marca o checkbox.
4. No momento do clique no checkbox, o sistema coleta:
   - **IP público** (via `api.ipify.org`)
   - **Timestamp** (UTC, ISO 8601)
   - **User-Agent** (navegador + sistema operacional)
   - **Geolocalização** (com permissão do navegador — opcional)
   - **Versão do contrato** (constante no JS)
   - **Hash SHA-256** do conteúdo HTML do contrato (prova de integridade)
   - **Referrer** + todos os URL params recebidos
5. Tudo é gravado em `contract_acceptances` no Supabase.
6. **Popup de obrigado** aparece com `nome / data / código de aceite`, instruindo o cliente a printar e enviar no grupo individual da Legacy.

---

## 🔧 Integração — passos para o desenvolvedor

### 1. Criar a tabela no Supabase

No **SQL Editor** do projeto Supabase, execute o conteúdo de [`schema.sql`](./schema.sql).

A tabela já vem com:
- Índices em `crm_contract_id`, `contractor_email`, `contractor_document`, `accepted_at`
- **RLS habilitado**: a `anon key` só pode `INSERT`, nunca `SELECT`. Leitura é apenas via `service_role` (CRM interno).

### 2. Configurar credenciais no `index.html`

No bloco `CONFIG` (início do `<script>`), preencher:

```js
const CONFIG = {
  SUPABASE_URL:      'https://<seu-projeto>.supabase.co',
  SUPABASE_ANON_KEY: '<sua-anon-key-pública>',
  CONTRACT_VERSION:  '1.0.0',
  TABLE_NAME:        'contract_acceptances',
  IP_API:            'https://api.ipify.org?format=json',
};
```

> A `anon_key` é pública e pode ficar no front-end — a RLS configurada limita o que ela faz (apenas INSERT).

### 3. Geração do link pelo CRM

Formato esperado da URL:

```
https://<dominio>/?id=<crm_id>
                  &nome=<nome|razao_social>
                  &cpf=<cpf|cnpj>
                  &email=<email>
                  &telefone=<telefone>     # opcional
                  &tipo=<PF|PJ>            # opcional
                  &modulos=<csv>           # opcional, ex: sovereignty,vanguard
                  &valor=<numero>          # opcional, ex: 10000
```

**Exemplo:**

```
https://aceite.legacy.com/
  ?id=CT-2026-00041
  &nome=Jo%C3%A3o%20Silva
  &cpf=12345678900
  &email=joao%40exemplo.com
  &tipo=PF
  &modulos=sovereignty,vanguard
  &valor=10000
```

> **Importante**: o CRM deve aplicar `encodeURIComponent()` em cada valor antes de montar a URL.

Aliases aceitos (caso o CRM use nomes em inglês):

| PT-BR (preferido) | EN (alias) |
|-------------------|-----------|
| `nome`            | `name` |
| `cpf`             | `cnpj`, `documento` |
| `telefone`        | `phone` |
| `tipo`            | `type` |
| `modulos`         | `modules` |
| `valor`           | `value` |

### 4. Versionamento do contrato

Sempre que o **texto do contrato** (HTML dentro de `#modal-overlay .modal`) for alterado:

1. Atualize `CONTRACT_VERSION` em `index.html` (ex: `1.0.0` → `1.1.0`).
2. O hash SHA-256 será recalculado automaticamente no carregamento da página e gravado em cada novo aceite — comprovando qual versão exata cada cliente assinou.

### 5. Deploy

A página é **100% estática** (HTML + JS + CDNs). Opções de hospedagem:

- **GitHub Pages** (grátis): Settings → Pages → Source: `main` / `(root)`.
- **Vercel / Netlify** (drag-and-drop ou via Git): suporta domínio customizado.

---

## 📊 Logs gravados (valor probatório)

Cada aceite registra na tabela `contract_acceptances`:

| Campo                | Origem                                  |
|----------------------|-----------------------------------------|
| `crm_contract_id`    | URL param `id`                          |
| `contractor_name`    | URL param `nome`                        |
| `contractor_document`| URL param `cpf` / `cnpj`                |
| `contractor_email`   | URL param `email`                       |
| `contractor_phone`   | URL param `telefone`                    |
| `contractor_type`    | URL param `tipo` (`PF` / `PJ`)          |
| `contracted_modules` | URL param `modulos` (array)             |
| `contracted_value`   | URL param `valor`                       |
| `accepted_at`        | `Date.now()` no momento do aceite       |
| `ip_address`         | `api.ipify.org`                         |
| `user_agent`         | `navigator.userAgent`                   |
| `geo_*`              | `navigator.geolocation` (com permissão) |
| `contract_version`   | `CONFIG.CONTRACT_VERSION`               |
| `document_hash`      | SHA-256 do texto do contrato            |
| `referrer`           | `document.referrer`                     |
| `url_params`         | Todos os params (jsonb)                 |

A combinação `accepted_at + ip_address + user_agent + document_hash + contract_version` atende ao registro técnico recomendado para checkboxes de contratos digitais (boa fé probatória).

---

## 🧪 Testes em ambiente local

Antes de configurar o Supabase, abra a página com URL params para ver o fluxo completo:

```
file:///path/to/index.html?id=TEST-001&nome=Joao%20Teste&cpf=12345678900&email=joao@test.com
```

Sem Supabase configurado, o payload aparece no console do navegador (`console.warn`) — útil para verificar formato antes de plugar a integração.

---

## 📁 Estrutura

```
P-gina-de-aceite-Legacy/
├── index.html      # página única (UI + lógica + estilos inline)
├── schema.sql      # DDL do Supabase (tabela + RLS)
└── README.md       # este arquivo
```
