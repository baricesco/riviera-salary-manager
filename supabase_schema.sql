-- Riviera Salary Manager v2 schema
-- Run this once in the Supabase SQL Editor (Project > SQL Editor > New query > Run).
-- Safe to re-run: every statement is "if not exists".

create extension if not exists pgcrypto;

-- Employees persist across months (name/role/date_left don't repeat per month).
create table if not exists riviera_employees (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  role text,
  date_left date,
  deleted boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

-- One row per employee per month: this month's base salary, days worked
-- (for half-month etc.), and the pending amount carried in from last month.
create table if not exists riviera_salary_months (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references riviera_employees(id),
  month text not null, -- 'YYYY-MM'
  base_salary numeric not null default 0,
  days_worked numeric, -- null = full month
  prev_pending numeric not null default 0,
  notes text,
  deleted boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  unique(employee_id, month)
);

-- Multiple payments can be logged against a single month.
create table if not exists riviera_salary_payments (
  id uuid primary key default gen_random_uuid(),
  salary_month_id uuid not null references riviera_salary_months(id) on delete cascade,
  amount numeric not null,
  pay_date date not null default current_date,
  note text,
  deleted boolean not null default false,
  created_at timestamptz not null default now()
);

alter table riviera_employees enable row level security;
alter table riviera_salary_months enable row level security;
alter table riviera_salary_payments enable row level security;

drop policy if exists "public all employees" on riviera_employees;
create policy "public all employees" on riviera_employees for all using (true) with check (true);

drop policy if exists "public all salary months" on riviera_salary_months;
create policy "public all salary months" on riviera_salary_months for all using (true) with check (true);

drop policy if exists "public all payments" on riviera_salary_payments;
create policy "public all payments" on riviera_salary_payments for all using (true) with check (true);

-- ---------------------------------------------------------------------
-- Groups / departments (Laundry, Kitchen, ...). Added later; re-running
-- the whole file is safe because these are "if not exists" too.
--   dept       : which group the person belongs to (null = Unassigned)
--   is_manager : marks this person as that group's manager. A group can
--                have a manager or no manager at all — both are fine.
-- ---------------------------------------------------------------------
alter table riviera_employees add column if not exists dept text;
alter table riviera_employees add column if not exists is_manager boolean not null default false;
create index if not exists riviera_employees_dept_idx on riviera_employees (dept);

-- How the money was handed over: 'Cash' or 'Online'. Older rows stay null,
-- which the app shows as Cash.
alter table riviera_salary_payments add column if not exists method text;
