import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:imagivet/models/question.dart';
import 'package:imagivet/state/game_controller.dart';
import 'package:imagivet/state/player_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Question> _questions() => [
  for (final e in jsonDecode(File('assets/questions.json').readAsStringSync()) as List)
    Question.fromJson(e as Map<String, dynamic>),
];

GameController _game(GameMode mode, {int seed = 1}) =>
    GameController(mode: mode, questions: _questions(), random: Random(seed));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('banco de questões: 10 do "Jogar agora" + 60 valendo pontos, com gabarito e explicações', () {
    final all = _questions();
    expect(all, hasLength(70));
    expect(all.map((q) => q.id).toSet(), hasLength(70), reason: 'ids únicos');
    String key(Iterable<Question> qs) => [for (final q in qs) 'ABCDE'[q.answer]].join();

    // "Jogar agora": as 10 perguntas principais (ids 11 a 20), gabarito C A E B D A E B C D.
    final teste = all.where((q) => q.set == QuestionSet.teste);
    expect([for (final q in teste) q.id], [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]);
    expect(key(teste), 'CAEBDAEBCD');

    // Valendo pontos: as 10 perguntas diretas (5 alternativas) + as 50 novas (4 alternativas).
    final valendo = all.where((q) => q.set == QuestionSet.valendo).toList();
    expect(valendo, hasLength(60));
    expect(key(valendo.take(10)), 'BCDADBECAD');
    expect(
      key(valendo.skip(10)),
      'BACDACBDAC'
      'BDACBDCACB'
      'CADBCADBAC'
      'BDACBDACBD'
      'ACDBCADBCA',
      reason: 'gabarito enviado pela equipe, bloco a bloco',
    );
    // Níveis da tela inicial: 1 a 5 com 10 questões cada e a fase final (6) com os casos clínicos.
    List<int> ids(int level) => [
      for (final q in valendo)
        if (q.level == level) q.id,
    ];
    expect(ids(1), [for (var i = 21; i <= 30; i++) i]);
    expect(ids(2), [for (var i = 31; i <= 40; i++) i]);
    expect(ids(3), [for (var i = 41; i <= 50; i++) i]);
    expect(ids(4), [for (var i = 51; i <= 60; i++) i]);
    expect(ids(5), [for (var i = 61; i <= 70; i++) i]);
    expect(ids(6), [for (var i = 1; i <= 10; i++) i], reason: 'casos clínicos = fase final');
    expect(teste.every((q) => q.level == null), isTrue, reason: 'o teste do "Jogar agora" não tem nível');

    for (final q in all) {
      expect(q.options.length, q.id <= 20 ? 5 : 4, reason: 'questão ${q.id}');
      expect(q.explanations, hasLength(q.options.length), reason: 'questão ${q.id}');
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.title, isNotEmpty);
    }
  });

  test('"Jogar agora" sem embaralhar: questões de 1 a 10 e alternativas de A a E, como no material', () {
    final teste = [
      for (final q in _questions())
        if (q.set == QuestionSet.teste) q,
    ];
    for (final seed in [1, 2, 3]) {
      final g = GameController(mode: GameMode.classic, questions: teste, random: Random(seed), shuffle: false);
      final ids = <int>[];
      for (var i = 0; i < 10; i++) {
        ids.add(g.item.question.id);
        for (var k = 0; k < g.item.length; k++) {
          expect(g.item.option(k), g.item.question.options[k], reason: 'alternativa ${'ABCDE'[k]} no lugar certo');
        }
        g.answer(g.item.originalIndex(g.item.question.answer));
        if (i < 9) g.next();
      }
      expect(ids, [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]);
      g.dispose();
    }
  });

  test('alternativas embaralhadas mantêm texto, explicação e gabarito', () {
    final q = _questions().first;
    final item = QuizItem.shuffled(q, Random(7));
    expect(item.option(item.correctIndex), q.options[q.answer]);
    expect(item.explanation(item.correctIndex), q.explanations[q.answer]);
  });

  test('combo multiplica os pontos: x1,5 com 3, x2 com 5, x3 com 8', () {
    expect(GameController.multiplierFor(2), 1);
    expect(GameController.multiplierFor(3), 1.5);
    expect(GameController.multiplierFor(5), 2);
    expect(GameController.multiplierFor(8), 3);

    final g = _game(GameMode.classic);
    final points = <int>[];
    for (var i = 0; i < 5; i++) {
      points.add(g.answer(g.item.correctIndex)!.points);
      g.next();
    }
    expect(g.combo, 5);
    // Respondendo na hora (tempo cheio), cada acerto vale 150 x multiplicador.
    expect(points, [150, 150, 225, 225, 300]);
    g.dispose();
  });

  test('errar ou deixar o tempo acabar custa uma vida e zera o combo', () {
    final g = _game(GameMode.classic);
    g.answer(g.item.correctIndex);
    g.next();
    final wrong = (g.item.correctIndex + 1) % g.item.length;
    expect(g.answer(wrong)!.correct, isFalse);
    expect(g.lives, 2);
    expect(g.combo, 0);
    g.next();
    for (var i = 0; i < 200 && !g.isAnswered; i++) {
      g.tick();
    }
    expect(g.outcome!.timedOut, isTrue);
    expect(g.lives, 1);
    g.dispose();
  });

  test('sem vidas, a partida acaba', () {
    final g = _game(GameMode.classic);
    for (var i = 0; i < 3; i++) {
      g.answer((g.item.correctIndex + 1) % g.item.length);
      g.next();
    }
    expect(g.finished, isTrue);
    expect(g.stars, 0);
    g.dispose();
  });

  test('clássico perfeito: 10 fases, 3 estrelas', () {
    final g = _game(GameMode.classic);
    for (var i = 0; i < 10; i++) {
      g.answer(g.item.correctIndex);
      g.next();
    }
    expect(g.finished, isTrue);
    expect(g.correct, 10);
    expect(g.stars, 3);
    expect(g.maxCombo, 10);
    g.dispose();
  });

  test('sobrevivência não acaba enquanto houver vidas (as questões voltam)', () {
    final g = _game(GameMode.survival);
    for (var i = 0; i < 25; i++) {
      g.answer(g.item.correctIndex);
      g.next();
    }
    expect(g.finished, isFalse);
    expect(g.correct, 25);
    // O tempo diminui conforme avança.
    expect(g.totalTime, lessThan(g.item.seconds));
    g.dispose();
  });

  test('50/50 remove duas erradas e nunca a certa', () {
    for (var seed = 0; seed < 20; seed++) {
      final g = _game(GameMode.classic, seed: seed);
      expect(g.apply(PowerUp.fiftyFifty), isTrue);
      expect(g.removed, hasLength(2));
      expect(g.removed.contains(g.item.correctIndex), isFalse);
      expect(g.apply(PowerUp.fiftyFifty), isFalse, reason: 'só uma vez por questão');
      g.dispose();
    }
  });

  test('+15s e pular funcionam sem perder vida', () {
    final g = _game(GameMode.classic);
    final before = g.timeLeft;
    g.apply(PowerUp.extraTime);
    expect(g.timeLeft, before + 15);
    final first = g.item.question.id;
    g.apply(PowerUp.skip);
    expect(g.item.question.id, isNot(first));
    expect(g.lives, 3);
    g.dispose();
  });

  group('progresso do jogador', () {
    test('níveis sobem com XP', () {
      final s = PlayerStore();
      expect(s.level, 1);
      s.xp = PlayerStore.xpForLevel(2);
      expect(s.level, 2);
      s.xp = PlayerStore.xpForLevel(4) + 10;
      expect(s.level, 4);
      expect(s.title, 'Residente');
    });

    test('ofensiva sobe em dias seguidos e zera se pular um dia', () async {
      var now = DateTime(2026, 11, 10, 9);
      final s = PlayerStore(clock: () => now);
      await s.load();
      const m = MatchSummary(
        mode: 'classic',
        score: 100,
        correct: 1,
        answered: 1,
        maxCombo: 1,
        xp: 10,
        coins: 5,
        stars: 0,
      );
      expect((await s.recordMatch(m)).streakDays, 1);
      expect((await s.recordMatch(m)).streakIncreased, isFalse, reason: 'mesmo dia');
      now = DateTime(2026, 11, 11, 20);
      expect((await s.recordMatch(m)).streakDays, 2);
      now = DateTime(2026, 11, 14, 8);
      expect(s.activeStreak, 0);
      expect((await s.recordMatch(m)).streakDays, 1);
    });

    test('níveis abrem em sequência e os casos clínicos só depois dos 5', () async {
      final s = PlayerStore();
      await s.load();
      MatchSummary match(int stars) => MatchSummary(
        mode: 'classic',
        score: 0,
        correct: stars == 0 ? 2 : 5,
        answered: 10,
        maxCombo: 0,
        xp: 0,
        coins: 0,
        stars: stars,
      );
      expect(s.isStageUnlocked(1), isTrue);
      expect(s.isStageUnlocked(2), isFalse);
      expect(s.isStageUnlocked(PlayerStore.finalStage), isFalse);

      // Sem estrela não conclui o nível.
      expect((await s.recordMatch(match(0), stage: 1)).stagePassed, isNull);
      expect(s.isStageUnlocked(2), isFalse);

      expect((await s.recordMatch(match(1), stage: 1)).stagePassed, 1);
      expect(s.isStageUnlocked(2), isTrue);
      expect((await s.recordMatch(match(3), stage: 1)).stagePassed, isNull, reason: 'já estava concluído');

      for (var stage = 2; stage <= 4; stage++) {
        await s.recordMatch(match(2), stage: stage);
      }
      expect(s.isStageUnlocked(5), isTrue);
      expect(s.isStageUnlocked(PlayerStore.finalStage), isFalse);
      expect(s.survivalUnlocked, isFalse, reason: 'Sobrevivência só depois do nível 5');
      await s.recordMatch(match(1), stage: 5);
      expect(s.isStageUnlocked(PlayerStore.finalStage), isTrue);
      expect(s.survivalUnlocked, isTrue);

      // Fica salvo no aparelho.
      final again = PlayerStore();
      await again.load();
      expect(again.passedStages, {1, 2, 3, 4, 5});
    });

    test('baú diário abre uma vez por dia', () async {
      var now = DateTime(2026, 11, 12);
      final s = PlayerStore(clock: () => now);
      await s.load();
      final start = s.coins;
      expect(await s.openChest(), PlayerStore.chestCoins);
      expect(await s.openChest(), 0);
      expect(s.coins, start + PlayerStore.chestCoins);
      now = DateTime(2026, 11, 13);
      expect(s.chestAvailable, isTrue);
    });

    test('ajudas só com saldo suficiente', () async {
      final s = PlayerStore();
      await s.load();
      s.coins = 25;
      expect(await s.spend(30), isFalse);
      expect(await s.spend(20), isTrue);
      expect(s.coins, 5);
    });
  });
}
