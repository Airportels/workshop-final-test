create table ft_codes (
  code text primary key,
  form text not null default 'A',
  label text,
  used_at timestamptz,
  submission_id uuid,
  created_at timestamptz default now()
);
create table ft_submissions (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  code text, form text, name text, email text, lang text,
  duration_seconds int, answered_count int, total_count int,
  answers jsonb, result_token uuid unique default gen_random_uuid()
);
create table ft_scores (
  submission_id uuid primary key references ft_submissions(id) on delete cascade,
  per_answer jsonb, objective_auto jsonb, total_points int,
  axis1 int, axis2 int, axis3 int, axis4 int, axis5 int,
  bucket text, notes text, released boolean default false,
  scored_by text, updated_at timestamptz default now()
);

alter table ft_codes enable row level security;
alter table ft_submissions enable row level security;
alter table ft_scores enable row level security;

-- participant validates a code and reads its form
-- single-use rule: only returns a form when the code exists AND has not yet been used
create or replace function redeem_code(p_code text) returns table(form text)
language plpgsql security definer as $$
begin
  return query select c.form from ft_codes c where c.code = p_code and c.used_at is null;
end $$;

-- participant submit (security definer so it can stamp codes without broad grants)
-- single-use rule: rejects codes that are already used or do not exist
create or replace function submit_test(
  p_code text, p_name text, p_email text, p_lang text,
  p_duration int, p_answered int, p_total int, p_answers jsonb
) returns table(id uuid, result_token uuid) language plpgsql security definer as $$
declare v_form text; v_id uuid; v_token uuid;
begin
  select c.form into v_form from ft_codes c where c.code = p_code and c.used_at is null;
  if v_form is null then raise exception 'invalid or already-used code'; end if;
  insert into ft_submissions(code,form,name,email,lang,duration_seconds,answered_count,total_count,answers)
    values (p_code,v_form,p_name,p_email,p_lang,p_duration,p_answered,p_total,p_answers)
    returning ft_submissions.id, ft_submissions.result_token into v_id, v_token;
  update ft_codes set used_at = now(), submission_id = v_id where code = p_code;
  return query select v_id, v_token;
end $$;

-- released result only; never returns correct answers
create or replace function get_result(p_token uuid) returns json
language plpgsql security definer as $$
declare v json; v_released boolean;
begin
  select coalesce(sc.released,false) into v_released
    from ft_submissions s left join ft_scores sc on sc.submission_id = s.id
    where s.result_token = p_token;
  if v_released is null then return json_build_object('found', false); end if;
  if v_released is not true then return json_build_object('found', true, 'released', false); end if;
  select json_build_object(
    'found', true, 'released', true,
    'name', s.name, 'total_points', sc.total_points,
    'per_answer', sc.per_answer, 'notes', sc.notes
  ) into v
  from ft_submissions s join ft_scores sc on sc.submission_id = s.id
  where s.result_token = p_token;
  return v;
end $$;

grant execute on function redeem_code(text) to anon;
grant execute on function submit_test(text,text,text,text,int,int,int,jsonb) to anon;
grant execute on function get_result(uuid) to anon;

-- facilitator (passcode-gated UI) uses anon select/upsert:
create policy fac_read_sub on ft_submissions for select to anon using (true);
create policy fac_read_scores on ft_scores for select to anon using (true);
create policy fac_write_scores on ft_scores for all to anon using (true) with check (true);
create policy fac_codes_all on ft_codes for all to anon using (true) with check (true);


-- Phase 4: questions in DB (lean; security low priority)
create table if not exists ft_questions (
  id text primary key,
  part text,
  ord int,
  type text,
  points int,
  variants jsonb,
  answer jsonb,
  updated_at timestamptz default now()
);
alter table ft_questions enable row level security;
drop policy if exists ftq_all on ft_questions;
create policy ftq_all on ft_questions for all to anon using (true) with check (true);
create or replace view ft_questions_public as
  select id, part, ord, type, points, variants from ft_questions;
grant select on ft_questions_public to anon;
