# Escopo: troféus, ligas e dificuldade progressiva

> Status: **aprovado, aguardando ordem para implementar** ("pode subir").
> Perguntas novas: ver [PERGUNTAS_AVANCADAS.md](PERGUNTAS_AVANCADAS.md) (aguardando revisão técnica).

## Objetivo

Deixar o ranking disputado e equilibrado: quem começa agora precisa ter chance real de alcançar quem
joga há meses, e o jogo deve ficar mais difícil quanto mais alto o jogador estiver.

## 1. Duas medidas separadas

| | O que mede | Pode diminuir? | Para que serve |
|---|---|---|---|
| **Nível / XP** | quanto a pessoa já estudou | **nunca** | título, conquistas, sensação de progresso |
| **🏆 Troféus** | quão bem a pessoa está jogando **agora** | **sim** | ranking, liga, dificuldade das perguntas |

- O ranking passa a ser por **troféus**.
- Os "pontos" de cada partida continuam existindo: viram a base para calcular o XP.
- Ícones: 🏆 troféus · ⭐ nota da partida (1 a 3) · 💎 diamantes (o nome "Moedas" passa a ser "Diamantes").

## 2. Ganho e perda por partida

O resultado é a **nota da partida**, as mesmas estrelas de hoje:

- Partida de 10: 9 ou 10 acertos = ⭐⭐⭐, 7 ou 8 = ⭐⭐, 5 ou 6 = ⭐, menos de 5 (ou perder as 3 vidas) = sem estrela.
- Sobrevivência: 15 acertos = ⭐⭐⭐, 8 = ⭐⭐, 3 = ⭐.

| Liga | Troféus | ⭐⭐⭐ | ⭐⭐ | ⭐ | Sem estrela |
|---|---|---|---|---|---|
| 🐣 Calouro | 0–299 | +30 | +20 | +10 | −5 |
| 🩺 Residente | 300–699 | +28 | +18 | +8 | −15 |
| 🔬 Clínico | 700–1199 | +25 | +15 | +5 | −20 |
| 🧠 Especialista | 1200–1799 | +22 | +12 | 0 | −25 |
| 🩻 Radiologista | 1800–2499 | +20 | +8 | −5 | −30 |
| 👑 Mestre da TC | 2500+ | +18 | +5 | −10 | −35 |

Regras que acompanham a tabela:

- **Piso de liga:** depois de chegar numa liga, o jogador não cai abaixo do início dela (exceto na virada de temporada).
- **Proteção de novato:** nas primeiras 10 partidas da conta, não se perde troféu.
- **Partida abandonada** conta como "sem estrela" (impede fugir de partida ruim).

## 3. Bônus de engajamento

| Bônus | Regra |
|---|---|
| 🔥 Sequência de vitórias | +3 troféus por vitória seguida (com 1 estrela ou mais), até +15. Zera ao perder. |
| ☀️ Primeira vitória do dia | troféus da partida **em dobro** (só ganhos, nunca perdas). |
| 🎉 Subiu de liga | tela especial com confete + **100 💎** (uma vez por liga por temporada). |
| 😬 "Quase lá" | no resultado: "faltam 12 🏆 para Clínico" / "você passou fulano no ranking". |
| 📊 Barra da liga | na tela inicial: progresso até a próxima liga. |

## 4. Temporadas

- Cada temporada dura **1 mês** e vira no dia 1º, à meia-noite de Brasília.
- **Reset parcial:** quem tem mais de 1000 🏆 perde metade do excedente.
  `novo = 1000 + (troféus − 1000) / 2`. Exemplo: 2600 → 1800. Quem tem 1000 ou menos não perde nada.
- Os 3 primeiros da temporada ganham medalha **🥇🥈🥉** permanente no perfil.
- O ranking ganha a aba **Temporada**, que vira a principal. As abas Semana e Geral continuam (Geral = recorde de troféus).

## 5. Dificuldade progressiva das perguntas

Cada pergunta ganha um campo `nivel` de 1 a 4:

| Nível | Conteúdo | Origem |
|---|---|---|
| 1 · Básico | perguntas diretas | as 10 da "Revisão rápida" (ids 11–20) |
| 2 · Intermediário | casos clínicos | as 10 "Perguntas principais" (ids 1–10) |
| 3 · Avançado | interpretação de imagem, técnica, diagnóstico diferencial | novas (ids 21–30) |
| 4 · Expert | cálculo, armadilhas, estadiamento, perícia | novas (ids 31–40) |

O sorteio da partida depende da liga do jogador:

| Liga | Nível 1 | Nível 2 | Nível 3 | Nível 4 | Tempo por questão |
|---|---|---|---|---|---|
| 🐣 Calouro | 60% | 40% | — | — | normal |
| 🩺 Residente | 30% | 50% | 20% | — | normal |
| 🔬 Clínico | 10% | 40% | 40% | 10% | normal |
| 🧠 Especialista | — | 20% | 50% | 30% | −10% |
| 🩻 Radiologista | — | 10% | 40% | 50% | −20% |
| 👑 Mestre da TC | — | — | 30% | 70% | −25% |

- Pergunta mais difícil vale mais: multiplicador de pontos ×1 / ×1,2 / ×1,5 / ×2 por nível.
- Os modos "Perguntas principais" e "Revisão rápida" continuam existindo como **treino** (não mexem em troféus).
  A partida **ranqueada** (botão principal) e a Sobrevivência usam o sorteio por liga.
- Com o tempo, mais perguntas devem entrar nos níveis 3 e 4 para não repetirem demais no topo.

## 6. Segurança (igual ao sistema atual)

Tudo é calculado no servidor (Supabase): troféus, liga, sorteio das questões, bônus e reset da temporada.
O navegador só envia a alternativa escolhida. O limite de tempo por resposta no servidor acompanha o
tempo reduzido das ligas altas.

## 7. O que muda no código (para a implementação)

- `supabase/schema.sql`
  - colunas novas em `profiles`: `trofeus`, `recorde_trofeus`, `liga_max_temporada`, `sequencia_vitorias`, `ultima_vitoria_dia`, `partidas_total`;
  - tabela `temporadas` e `medalhas`;
  - `gabarito.nivel`;
  - `iniciar_partida` passa a sortear as questões por liga;
  - `finalizar_partida` calcula os troféus;
  - `ranking` ganha o período `temporada`;
  - função de virada de temporada (agendada com `pg_cron` ou executada na primeira partida do mês).
- `assets/questions.json`: campo `nivel` em todas as questões + as 20 novas.
- App: troféus e liga na tela inicial, no resultado (ganho/perda animado), no perfil e no ranking; tela "subiu de liga"; troca de 💎 "Moedas" para "Diamantes" e do ícone dos pontos.
- Testes: tabela de troféus, piso de liga, proteção de novato, reset de temporada, sorteio por liga.
