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

  test('banco de questões: 10 principais + 10 casos clínicos, 5 alternativas, gabarito e explicações', () {
    final all = _questions();
    expect(all, hasLength(20));
    expect(all.map((q) => q.id).toSet(), hasLength(20), reason: 'ids únicos');
    final principais = [
      for (final q in all)
        if (q.set == QuestionSet.principais) q,
    ];
    expect([for (final q in principais) 'ABCDE'[q.answer]].join(), 'CAEBDAEBCD');
    final qs = [
      for (final q in all)
        if (q.set == QuestionSet.casos) q,
    ];
    expect(qs, hasLength(10));
    for (final q in qs) {
      expect(q.options, hasLength(5), reason: 'questão ${q.id}');
      expect(q.explanations, hasLength(5), reason: 'questão ${q.id}');
      expect(q.answer, inInclusiveRange(0, 4));
    }
    // Gabarito dos casos clínicos enviado pela equipe: B, C, D, A, D, B, E, C, A, D.
    expect([for (final q in qs) 'ABCDE'[q.answer]].join(), 'BCDADBECAD');
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
