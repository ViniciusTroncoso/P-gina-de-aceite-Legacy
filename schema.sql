-- ============================================================
-- Supabase schema: registros de aceite do contrato Legacy
-- Executar uma vez no SQL Editor do projeto Supabase.
-- ============================================================

create table if not exists public.contract_acceptances (
  id uuid primary key default gen_random_uuid(),

  -- Dados vindos via URL param do CRM
  crm_contract_id      text,
  contractor_name      text,
  contractor_document  text,           -- CPF ou CNPJ
  contractor_email     text,
  contractor_phone     text,
  contractor_type      text,           -- 'PF' | 'PJ'
  contracted_modules   text[],         -- ex: {sovereignty, dominance}
  contracted_value     numeric(10, 2),

  -- Aceite (registro técnico-jurídico)
  accepted_at          timestamptz not null default now(),
  ip_address           inet,
  user_agent           text,
  geo_latitude         double precision,
  geo_longitude        double precision,
  geo_accuracy         double precision,

  -- Integridade do documento
  contract_version     text not null,
  document_hash        text not null,  -- SHA-256 do contrato no momento do aceite

  -- Metadados extras
  referrer             text,
  url_params           jsonb,

  -- Auditoria
  created_at           timestamptz not null default now()
);

-- Índices para consultas rápidas no CRM
create index if not exists contract_acceptances_crm_id_idx
  on public.contract_acceptances (crm_contract_id);
create index if not exists contract_acceptances_email_idx
  on public.contract_acceptances (contractor_email);
create index if not exists contract_acceptances_document_idx
  on public.contract_acceptances (contractor_document);
create index if not exists contract_acceptances_accepted_at_idx
  on public.contract_acceptances (accepted_at desc);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table public.contract_acceptances enable row level security;

-- Front-end (anon key) só pode INSERIR — não consegue ler aceites alheios.
create policy "anon insert acceptances"
  on public.contract_acceptances
  for insert
  to anon
  with check (true);

-- IMPORTANTE: NÃO criar policy de SELECT/UPDATE/DELETE para anon.
-- Leitura/edição apenas via service_role (backend / CRM interno).
