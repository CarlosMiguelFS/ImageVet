-- ImagiVet: banco completo (perfil, partidas, pontuação, ranking, LGPD).
-- Feito por Carlos Miguel Fernandes dos Santos.
--
-- Como usar: no projeto Supabase do ImagiVet (NÃO no do SuturaVet), abra
-- SQL Editor > New query, cole este arquivo inteiro e clique em Run.
-- Pode ser rodado de novo sem problema (é idempotente).
--
-- Segurança
-- * Cada jogador lê e edita só o próprio perfil, e só nome, turma, foto e ranking.
-- * Pontos, moedas, XP, recordes e ofensiva só mudam pelas funções do jogo, que
--   rodam no servidor: o app manda só "qual alternativa marquei" e o servidor
--   confere no gabarito, calcula combo, pontos, moedas, estrelas e XP.
-- * Cada partida tem dono, vidas, combo e lista de questões no servidor:
--   não dá para responder a mesma questão duas vezes no Clássico, jogar sem
--   vidas, responder mais rápido que um humano ou passar do teto diário.
-- * Ajudas (50/50, +15s, Pular) descontam moedas no servidor.
-- * O ranking mostra só posição, nome, turma, foto, nível e pontos (nunca e-mail ou id).
-- * Cada jogador só envia ou apaga fotos dentro da própria pasta.
--
-- LGPD
-- * Registra quando e qual versão dos termos o jogador aceitou; sem aceite, nada é pontuado.
-- * meus_dados() devolve tudo o que está guardado (acesso);
--   excluir_minha_conta() apaga conta, perfil, partidas e respostas (eliminação).
-- * Partidas e respostas com mais de 1 ano são apagadas automaticamente (retenção).

-- ---------------------------------------------------------------------------
-- Perfis
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null default ''
    check (char_length(nome) <= 60 and nome !~ '[[:cntrl:]]'),
  turma text
    check (turma is null or (char_length(turma) <= 40 and turma !~ '[[:cntrl:]]')),
  avatar_path text,
  -- Todo jogador aparece no ranking; pode sair no perfil (direito de oposição).
  no_ranking boolean not null default true,
  -- Progresso do jogo (só as funções do servidor alteram).
  pontos integer not null default 0 check (pontos >= 0),
  xp integer not null default 0 check (xp >= 0),
  moedas integer not null default 100 check (moedas >= 0),
  respondidas integer not null default 0 check (respondidas >= 0),
  acertos integer not null default 0 check (acertos >= 0),
  partidas integer not null default 0 check (partidas >= 0),
  melhor_classico integer not null default 0 check (melhor_classico >= 0),
  melhor_estrelas smallint not null default 0 check (melhor_estrelas between 0 and 3),
  melhor_sobrevivencia integer not null default 0 check (melhor_sobrevivencia >= 0),
  melhor_combo integer not null default 0 check (melhor_combo >= 0),
  dias_seguidos integer not null default 0 check (dias_seguidos >= 0),
  ultimo_dia_jogado date,
  bau_dia date,
  respostas_dia date,
  respostas_no_dia integer not null default 0,
  termos_aceitos_em timestamptz,
  termos_versao text check (termos_versao is null or char_length(termos_versao) <= 20),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  -- A foto precisa estar na pasta do próprio jogador: "<id>/<arquivo>".
  constraint avatar_na_pasta_do_dono check (
    avatar_path is null
    or (char_length(avatar_path) <= 200
        and avatar_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]+$'
        and split_part(avatar_path, '/', 1) = id::text)
  )
);

alter table public.profiles enable row level security;

drop policy if exists "perfil: dono le" on public.profiles;
create policy "perfil: dono le" on public.profiles
  for select to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "perfil: dono atualiza" on public.profiles;
create policy "perfil: dono atualiza" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Permissões por coluna: o jogador só consegue alterar estes quatro campos.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (nome, turma, avatar_path, no_ranking) on public.profiles to authenticated;

create or replace function public.tocar_atualizado_em()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

drop trigger if exists perfil_atualizado_em on public.profiles;
create trigger perfil_atualizado_em
  before update on public.profiles
  for each row execute function public.tocar_atualizado_em();

-- Cria o perfil no cadastro (e-mail ou Google). No cadastro por e-mail o app
-- envia a versão dos termos aceita; no Google o aceite é pedido no 1º acesso.
create or replace function public.criar_perfil()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_versao text := left(new.raw_user_meta_data ->> 'termos_versao', 20);
begin
  insert into public.profiles (id, nome, termos_versao, termos_aceitos_em)
  values (
    new.id,
    left(regexp_replace(
      coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
      '[[:cntrl:]]', '', 'g'), 60),
    v_versao,
    case when v_versao is not null then now() end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario
  after insert on auth.users
  for each row execute function public.criar_perfil();

insert into public.profiles (id, nome)
select
  u.id,
  left(regexp_replace(
    coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', ''),
    '[[:cntrl:]]', '', 'g'), 60)
from auth.users u
on conflict (id) do nothing;

create or replace function public.aceitar_termos(p_versao text)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_perfil public.profiles;
begin
  if (select auth.uid()) is null then
    raise exception 'Não autenticado' using errcode = '28000';
  end if;
  if p_versao is null or char_length(p_versao) > 20 then
    raise exception 'Versão inválida' using errcode = '22023';
  end if;
  update public.profiles
     set termos_versao = p_versao, termos_aceitos_em = now()
   where id = (select auth.uid())
  returning * into v_perfil;
  return v_perfil;
end;
$$;

revoke all on function public.aceitar_termos(text) from public, anon;
grant execute on function public.aceitar_termos(text) to authenticated;

-- Dia de referência do jogo (horário de Brasília), usado no baú e na ofensiva.
create or replace function public.hoje_br()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'America/Sao_Paulo')::date;
$$;

-- ---------------------------------------------------------------------------
-- Gabarito (nenhum acesso direto pelo app)
-- ---------------------------------------------------------------------------
create table if not exists public.gabarito (
  questao_id integer primary key,
  resposta smallint not null check (resposta between 0 and 4),
  total_alternativas smallint not null check (total_alternativas between 2 and 5)
);
alter table public.gabarito enable row level security;
revoke all on public.gabarito from anon, authenticated;

-- Índice da alternativa correta (0 = A) na ordem de assets/questions.json.
-- Só entram as questões que valem pontos. As 10 do "Modo teste" (ids 1 a 10)
-- ficam fora: o app corrige localmente e não envia nada ao servidor.
delete from public.gabarito where questao_id between 1 and 10;

insert into public.gabarito (questao_id, resposta, total_alternativas) values
  -- Perguntas diretas (5 alternativas)
  (11, 2, 5),
  (12, 0, 5),
  (13, 4, 5),
  (14, 1, 5),
  (15, 3, 5),
  (16, 0, 5),
  (17, 4, 5),
  (18, 1, 5),
  (19, 2, 5),
  (20, 3, 5),
  -- Perguntas novas (4 alternativas): nível 1, 2 e 3
  (21, 1, 4),
  (22, 0, 4),
  (23, 2, 4),
  (24, 3, 4),
  (25, 0, 4),
  (26, 2, 4),
  (27, 1, 4),
  (28, 3, 4),
  (29, 0, 4),
  (30, 2, 4),
  (31, 1, 4),
  (32, 3, 4),
  (33, 0, 4),
  (34, 2, 4),
  (35, 1, 4),
  (36, 3, 4),
  (37, 2, 4),
  (38, 0, 4),
  (39, 2, 4),
  (40, 1, 4),
  (41, 2, 4),
  (42, 0, 4),
  (43, 3, 4),
  (44, 1, 4),
  (45, 2, 4),
  (46, 0, 4),
  (47, 3, 4),
  (48, 1, 4),
  (49, 0, 4),
  (50, 2, 4),
  (51, 1, 4),
  (52, 3, 4),
  (53, 0, 4),
  (54, 2, 4),
  (55, 1, 4),
  (56, 3, 4),
  (57, 0, 4),
  (58, 2, 4),
  (59, 1, 4),
  (60, 3, 4),
  (61, 0, 4),
  (62, 2, 4),
  (63, 3, 4),
  (64, 1, 4),
  (65, 2, 4),
  (66, 0, 4),
  (67, 3, 4),
  (68, 1, 4),
  (69, 2, 4),
  (70, 0, 4)
on conflict (questao_id) do update set
  resposta = excluded.resposta,
  total_alternativas = excluded.total_alternativas;

-- ---------------------------------------------------------------------------
-- Partidas e respostas (nenhum acesso direto pelo app)
-- ---------------------------------------------------------------------------
create table if not exists public.partidas (
  id uuid primary key default gen_random_uuid(),
  jogador uuid not null references auth.users (id) on delete cascade,
  modo text not null check (modo in ('classic', 'survival')),
  ativa boolean not null default true,
  vidas smallint not null default 3,
  combo integer not null default 0,
  max_combo integer not null default 0,
  pontos integer not null default 0,
  acertos integer not null default 0,
  respondidas integer not null default 0,
  moedas integer not null default 0,
  questoes integer[] not null default '{}',
  estrelas smallint,
  xp integer,
  ultima_acao timestamptz,
  iniciada_em timestamptz not null default now(),
  encerrada_em timestamptz
);
create index if not exists partidas_jogador on public.partidas (jogador, iniciada_em desc);
create index if not exists partidas_semana on public.partidas (iniciada_em) where pontos > 0;
alter table public.partidas enable row level security;
revoke all on public.partidas from anon, authenticated;

create table if not exists public.respostas (
  id bigint generated always as identity primary key,
  jogador uuid not null references auth.users (id) on delete cascade,
  partida uuid not null references public.partidas (id) on delete cascade,
  questao_id integer not null,
  correta boolean not null,
  pontos integer not null,
  criado_em timestamptz not null default now()
);
create index if not exists respostas_jogador on public.respostas (jogador, criado_em desc);
alter table public.respostas enable row level security;
revoke all on public.respostas from anon, authenticated;

-- Fecha uma partida: estrelas, XP, bônus de moedas, recordes e ofensiva diária.
-- Uso interno (o app chama finalizar_partida).
create or replace function public.encerrar_partida_interna(p_partida uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.partidas;
  v_perfil public.profiles;
  v_estrelas smallint;
  v_xp integer;
  v_bonus integer;
  v_recorde boolean := false;
  v_hoje date := public.hoje_br();
  v_subiu boolean := false;
begin
  select * into v from public.partidas where id = p_partida for update;
  if not found or not v.ativa then
    return null;
  end if;

  -- Mesmas regras do app (lib/state/game_controller.dart).
  if v.modo = 'survival' then
    v_estrelas := case when v.acertos >= 15 then 3 when v.acertos >= 8 then 2 when v.acertos >= 3 then 1 else 0 end;
  elsif v.vidas <= 0 then
    v_estrelas := 0;
  else
    v_estrelas := case when v.acertos >= 9 then 3 when v.acertos >= 7 then 2 when v.acertos >= 5 then 1 else 0 end;
  end if;
  v_xp := round(v.pontos / 5.0)::integer + v.acertos * 10 + v_estrelas * 25;
  v_bonus := v_estrelas * 10;

  update public.partidas
     set ativa = false, estrelas = v_estrelas, xp = v_xp, moedas = moedas + v_bonus, encerrada_em = now()
   where id = v.id;

  select * into v_perfil from public.profiles where id = v.jogador for update;
  if v.modo = 'survival' then
    v_recorde := v.acertos > v_perfil.melhor_sobrevivencia;
  else
    v_recorde := v.pontos > v_perfil.melhor_classico;
  end if;
  -- Só conta para a ofensiva quem respondeu alguma questão.
  v_subiu := v.respondidas > 0 and v_perfil.ultimo_dia_jogado is distinct from v_hoje;

  update public.profiles set
    xp = xp + v_xp,
    moedas = moedas + v_bonus,
    partidas = partidas + 1,
    melhor_classico = case when v.modo = 'classic' then greatest(melhor_classico, v.pontos) else melhor_classico end,
    melhor_estrelas = case when v.modo = 'classic' then greatest(melhor_estrelas, v_estrelas) else melhor_estrelas end,
    melhor_sobrevivencia = case when v.modo = 'survival' then greatest(melhor_sobrevivencia, v.acertos)
                                else melhor_sobrevivencia end,
    dias_seguidos = case
      when not v_subiu then dias_seguidos
      when ultimo_dia_jogado = v_hoje - 1 then dias_seguidos + 1
      else 1 end,
    ultimo_dia_jogado = case when v_subiu then v_hoje else ultimo_dia_jogado end
  where id = v.jogador
  returning * into v_perfil;

  return jsonb_build_object(
    'estrelas', v_estrelas,
    'xp', v_xp,
    'moedas', v.moedas + v_bonus,
    'pontos', v.pontos,
    'acertos', v.acertos,
    'respondidas', v.respondidas,
    'max_combo', v.max_combo,
    'vidas', v.vidas,
    'novo_recorde', v_recorde,
    'ofensiva_subiu', v_subiu,
    'perfil', to_jsonb(v_perfil)
  );
end;
$$;

revoke all on function public.encerrar_partida_interna(uuid) from public, anon, authenticated;

create or replace function public.iniciar_partida(p_modo text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_perfil public.profiles;
  v_antiga uuid;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Não autenticado' using errcode = '28000';
  end if;
  if p_modo is null or p_modo not in ('classic', 'survival') then
    raise exception 'Modo inválido' using errcode = '22023';
  end if;
  select * into v_perfil from public.profiles where id = v_uid;
  if not found then
    raise exception 'Perfil não encontrado' using errcode = 'P0002';
  end if;
  if v_perfil.termos_aceitos_em is null then
    raise exception 'Aceite os termos para registrar seu progresso' using errcode = '42501';
  end if;
  if (select count(*) from public.partidas
       where jogador = v_uid and iniciada_em > now() - interval '1 day') >= 150 then
    raise exception 'Limite diário de partidas atingido' using errcode = '54000';
  end if;

  -- Uma partida por vez: as abandonadas são encerradas agora.
  for v_antiga in select id from public.partidas where jogador = v_uid and ativa loop
    perform public.encerrar_partida_interna(v_antiga);
  end loop;

  insert into public.partidas (jogador, modo) values (v_uid, p_modo) returning id into v_id;

  -- Retenção: apaga partidas (e respostas) com mais de 1 ano, de vez em quando.
  if random() < 0.02 then
    delete from public.partidas where iniciada_em < now() - interval '1 year';
  end if;
  return v_id;
end;
$$;

revoke all on function public.iniciar_partida(text) from public, anon;
grant execute on function public.iniciar_partida(text) to authenticated;

-- Busca a partida ativa do jogador logado (trava a linha para atualizar).
create or replace function public.partida_do_jogador(p_partida uuid)
returns public.partidas
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.partidas;
begin
  select * into v from public.partidas
   where id = p_partida and jogador = (select auth.uid())
   for update;
  if not found or not v.ativa or v.iniciada_em < now() - interval '3 hours' then
    raise exception 'Partida encerrada' using errcode = '22023';
  end if;
  return v;
end;
$$;

revoke all on function public.partida_do_jogador(uuid) from public, anon, authenticated;

create or replace function public.responder(
  p_partida uuid,
  p_questao_id integer,
  p_alternativa integer,
  p_tempo_restante integer,
  p_tempo_total integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v public.partidas;
  v_perfil public.profiles;
  v_gabarito public.gabarito;
  v_correta boolean;
  v_mult numeric := 1;
  v_pontos integer := 0;
  v_moedas integer := 0;
begin
  if v_uid is null then
    raise exception 'Não autenticado' using errcode = '28000';
  end if;
  v := public.partida_do_jogador(p_partida);
  if v.vidas <= 0 then
    raise exception 'Sem vidas' using errcode = '22023';
  end if;

  select * into v_gabarito from public.gabarito where questao_id = p_questao_id;
  if not found then
    raise exception 'Questão inválida' using errcode = '22023';
  end if;
  -- p_alternativa nula = tempo esgotado. O tempo total vai de 15 s a 70 s (+15 s da ajuda).
  if (p_alternativa is not null and (p_alternativa < 0 or p_alternativa >= v_gabarito.total_alternativas))
     or p_tempo_total is null or p_tempo_total < 15 or p_tempo_total > 85
     or p_tempo_restante is null or p_tempo_restante < 0 or p_tempo_restante > p_tempo_total then
    raise exception 'Resposta inválida' using errcode = '22023';
  end if;
  -- No Clássico: 10 questões, cada uma uma vez só.
  if v.modo = 'classic' and (p_questao_id = any (v.questoes) or cardinality(v.questoes) >= 10) then
    raise exception 'Questão já respondida' using errcode = '22023';
  end if;
  -- Ninguém lê e responde em menos de 2 segundos.
  if v.ultima_acao is not null and now() - v.ultima_acao < interval '2 seconds' then
    raise exception 'Respostas rápidas demais' using errcode = '54000';
  end if;

  select * into v_perfil from public.profiles where id = v_uid for update;
  if v_perfil.termos_aceitos_em is null then
    raise exception 'Aceite os termos para registrar seu progresso' using errcode = '42501';
  end if;
  if v_perfil.respostas_dia = public.hoje_br() and v_perfil.respostas_no_dia >= 300 then
    raise exception 'Limite diário de respostas atingido' using errcode = '54000';
  end if;

  v_correta := p_alternativa is not null and p_alternativa = v_gabarito.resposta;

  -- Mesmas regras do app: combo 3 = x1.5, 5 = x2, 8 = x3; bônus de até 50% pelo tempo.
  if v_correta then
    v.combo := v.combo + 1;
    v_mult := case when v.combo >= 8 then 3 when v.combo >= 5 then 2 when v.combo >= 3 then 1.5 else 1 end;
    v_pontos := round((100 + 50.0 * p_tempo_restante / p_tempo_total) * v_mult)::integer;
    v_moedas := 5 + case when v.combo % 3 = 0 then 5 else 0 end;
  else
    v.combo := 0;
    v.vidas := v.vidas - 1;
  end if;

  update public.partidas set
    vidas = v.vidas,
    combo = v.combo,
    max_combo = greatest(max_combo, v.combo),
    pontos = pontos + v_pontos,
    acertos = acertos + case when v_correta then 1 else 0 end,
    respondidas = respondidas + 1,
    moedas = moedas + v_moedas,
    questoes = case when modo = 'classic' then questoes || p_questao_id else questoes end,
    ultima_acao = now()
  where id = v.id
  returning * into v;

  update public.profiles set
    pontos = pontos + v_pontos,
    moedas = moedas + v_moedas,
    respondidas = respondidas + 1,
    acertos = acertos + case when v_correta then 1 else 0 end,
    melhor_combo = greatest(melhor_combo, v.combo),
    respostas_no_dia = case when respostas_dia = public.hoje_br() then respostas_no_dia + 1 else 1 end,
    respostas_dia = public.hoje_br()
  where id = v_uid
  returning * into v_perfil;

  insert into public.respostas (jogador, partida, questao_id, correta, pontos)
  values (v_uid, v.id, p_questao_id, v_correta, v_pontos);

  return jsonb_build_object(
    'correta', v_correta,
    'pontos', v_pontos,
    'moedas', v_moedas,
    'combo', v.combo,
    'vidas', v.vidas,
    'perfil', to_jsonb(v_perfil)
  );
end;
$$;

revoke all on function public.responder(uuid, integer, integer, integer, integer) from public, anon;
grant execute on function public.responder(uuid, integer, integer, integer, integer) to authenticated;

-- Ajudas pagas com moedas: 50/50 (30), +15s (20) e Pular (40).
create or replace function public.usar_ajuda(p_partida uuid, p_ajuda text, p_questao_id integer)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.partidas;
  v_perfil public.profiles;
  v_custo integer := case p_ajuda when 'fiftyFifty' then 30 when 'extraTime' then 20 when 'skip' then 40 end;
begin
  if (select auth.uid()) is null then
    raise exception 'Não autenticado' using errcode = '28000';
  end if;
  if v_custo is null or not exists (select 1 from public.gabarito where questao_id = p_questao_id) then
    raise exception 'Ajuda inválida' using errcode = '22023';
  end if;
  v := public.partida_do_jogador(p_partida);
  if v.modo = 'classic' and (p_questao_id = any (v.questoes) or cardinality(v.questoes) >= 10) then
    raise exception 'Questão já respondida' using errcode = '22023';
  end if;

  update public.profiles set moedas = moedas - v_custo
   where id = (select auth.uid()) and moedas >= v_custo
  returning * into v_perfil;
  if not found then
    raise exception 'Moedas insuficientes' using errcode = 'P0001';
  end if;

  -- Pular gasta a vaga da questão no Clássico.
  if p_ajuda = 'skip' and v.modo = 'classic' then
    update public.partidas set questoes = questoes || p_questao_id where id = v.id;
  end if;
  return v_perfil;
end;
$$;

revoke all on function public.usar_ajuda(uuid, text, integer) from public, anon;
grant execute on function public.usar_ajuda(uuid, text, integer) to authenticated;

create or replace function public.finalizar_partida(p_partida uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.partidas;
begin
  if (select auth.uid()) is null then
    raise exception 'Não autenticado' using errcode = '28000';
  end if;
  v := public.partida_do_jogador(p_partida);
  return public.encerrar_partida_interna(v.id);
end;
$$;

revoke all on function public.finalizar_partida(uuid) from public, anon;
grant execute on function public.finalizar_partida(uuid) to authenticated;

-- Baú diário: +50 moedas uma vez por dia (horário de Brasília).
create or replace function public.abrir_bau()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_perfil public.profiles;
begin
  if (select auth.uid()) is null then
    raise exception 'Não autenticado' using errcode = '28000';
  end if;
  update public.profiles set moedas = moedas + 50, bau_dia = public.hoje_br()
   where id = (select auth.uid()) and bau_dia is distinct from public.hoje_br()
     and termos_aceitos_em is not null
  returning * into v_perfil;
  if found then
    return jsonb_build_object('ganhou', 50, 'perfil', to_jsonb(v_perfil));
  end if;
  select * into v_perfil from public.profiles where id = (select auth.uid());
  return jsonb_build_object('ganhou', 0, 'perfil', to_jsonb(v_perfil));
end;
$$;

revoke all on function public.abrir_bau() from public, anon;
grant execute on function public.abrir_bau() to authenticated;

-- ---------------------------------------------------------------------------
-- Ranking: geral (pontos acumulados) ou da semana (segunda a domingo).
-- Só dados públicos; o próprio jogador sempre vem, mesmo fora do top.
-- ---------------------------------------------------------------------------
drop function if exists public.ranking(text, integer);
create or replace function public.ranking(p_periodo text default 'geral', p_limite integer default 50)
returns table (
  posicao bigint,
  nome text,
  turma text,
  avatar_path text,
  pontos integer,
  xp integer,
  eu boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with semana as (
    select pa.jogador, sum(pa.pontos)::integer as pontos
      from public.partidas pa
     where pa.pontos > 0
       and pa.iniciada_em >= (date_trunc('week', now() at time zone 'America/Sao_Paulo')
                              at time zone 'America/Sao_Paulo')
     group by pa.jogador
  ),
  base as (
    select p.id, p.nome, p.turma, p.avatar_path, p.xp, p.criado_em,
           case when p_periodo = 'semana' then coalesce(s.pontos, 0) else p.pontos end as pontos
      from public.profiles p
      left join semana s on s.jogador = p.id
     where p.no_ranking and p.termos_aceitos_em is not null
  ),
  ordenado as (
    select row_number() over (order by b.pontos desc, b.xp desc, b.criado_em) as posicao, b.*
      from base b
     where b.pontos > 0 or b.id = (select auth.uid())
  )
  select o.posicao, o.nome, o.turma, o.avatar_path, o.pontos, o.xp,
         o.id = (select auth.uid()) as eu
    from ordenado o
   where o.posicao <= least(greatest(coalesce(p_limite, 50), 1), 100)
      or o.id = (select auth.uid())
   order by o.posicao;
$$;

revoke all on function public.ranking(text, integer) from public, anon;
grant execute on function public.ranking(text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- "Esqueci minha senha": confere se o e-mail tem conta, com limite por IP
-- (10 consultas por minuto) para um robô não descobrir quem é cadastrado.
-- ---------------------------------------------------------------------------
create table if not exists public.limite_consultas (
  chave text not null,
  janela timestamptz not null,
  total integer not null default 0,
  primary key (chave, janela)
);
alter table public.limite_consultas enable row level security;
revoke all on public.limite_consultas from anon, authenticated;

create or replace function public.email_cadastrado(p_email text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ip text := coalesce(
    nullif(split_part(current_setting('request.headers', true)::json ->> 'x-forwarded-for', ',', 1), ''),
    'desconhecido'
  );
  v_janela timestamptz := date_trunc('minute', now());
  v_total integer;
begin
  if p_email is null or char_length(p_email) > 254 then
    return false;
  end if;
  insert into public.limite_consultas as l (chave, janela, total)
  values ('email:' || v_ip, v_janela, 1)
  on conflict (chave, janela) do update set total = l.total + 1
  returning total into v_total;

  if v_total > 10 then
    raise exception 'Muitas tentativas. Aguarde um minuto.' using errcode = '54000';
  end if;
  if random() < 0.02 then
    delete from public.limite_consultas where janela < now() - interval '1 day';
  end if;

  return exists (select 1 from auth.users where lower(email) = lower(trim(p_email)));
end;
$$;

revoke all on function public.email_cadastrado(text) from public;
grant execute on function public.email_cadastrado(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- LGPD: acesso e eliminação
-- ---------------------------------------------------------------------------
create or replace function public.meus_dados()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'conta', (
      select jsonb_build_object(
        'email', u.email,
        'criada_em', u.created_at,
        'ultimo_acesso', u.last_sign_in_at,
        'provedores', u.raw_app_meta_data -> 'providers'
      )
      from auth.users u where u.id = (select auth.uid())
    ),
    'perfil', (select to_jsonb(p) from public.profiles p where p.id = (select auth.uid())),
    'partidas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'modo', pa.modo, 'pontos', pa.pontos, 'acertos', pa.acertos, 'respondidas', pa.respondidas,
        'estrelas', pa.estrelas, 'xp', pa.xp, 'moedas', pa.moedas, 'em', pa.iniciada_em
      ) order by pa.iniciada_em desc)
      from public.partidas pa where pa.jogador = (select auth.uid())
    ), '[]'::jsonb),
    'respostas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'questao', r.questao_id, 'correta', r.correta, 'pontos', r.pontos, 'em', r.criado_em
      ) order by r.criado_em desc)
      from public.respostas r where r.jogador = (select auth.uid())
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.meus_dados() from public, anon;
grant execute on function public.meus_dados() to authenticated;

-- O app apaga a foto pelo Storage antes de chamar esta função.
create or replace function public.excluir_minha_conta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Não autenticado' using errcode = '28000';
  end if;
  -- Perfil, partidas e respostas saem junto (on delete cascade).
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.excluir_minha_conta() from public, anon;
grant execute on function public.excluir_minha_conta() to authenticated;

-- Funções auxiliares não podem ser chamadas pelo app.
revoke all on function public.hoje_br() from public, anon, authenticated;
revoke all on function public.tocar_atualizado_em() from public, anon, authenticated;
revoke all on function public.criar_perfil() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Fotos de perfil (Storage)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatar: dono le" on storage.objects;
create policy "avatar: dono le" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "avatar: dono envia" on storage.objects;
create policy "avatar: dono envia" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "avatar: dono atualiza" on storage.objects;
create policy "avatar: dono atualiza" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "avatar: dono apaga" on storage.objects;
create policy "avatar: dono apaga" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
