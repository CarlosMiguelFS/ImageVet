import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/question.dart';
import 'player_store.dart';

enum GameMode {
  classic('classic', 'Clássico'),
  survival('survival', 'Sobrevivência');

  const GameMode(this.id, this.label);
  final String id;
  final String label;
}

enum PowerUp {
  fiftyFifty('50/50', '✂️', 30),
  extraTime('+15s', '⏱️', 20),
  skip('Pular', '⏭️', 40);

  const PowerUp(this.label, this.emoji, this.cost);
  final String label;
  final String emoji;
  final int cost;
}

/// Resultado da última resposta, para o painel de feedback.
class AnswerOutcome {
  const AnswerOutcome({
    required this.selected,
    required this.correct,
    required this.points,
    required this.multiplier,
    required this.coins,
    required this.timedOut,
  });

  final int? selected;
  final bool correct;
  final int points;
  final double multiplier;
  final int coins;
  final bool timedOut;
}

/// Regras de uma partida. Não depende de tela, para poder ser testado.
class GameController extends ChangeNotifier {
  GameController({required this.mode, required List<Question> questions, Random? random, this.lives = 3})
    : _pool = questions,
      _rng = random ?? Random() {
    _refill();
    _startQuestion();
  }

  static const classicLength = 10;
  static const coinsPerCorrect = 5;

  final GameMode mode;
  final List<Question> _pool;
  final Random _rng;
  final List<QuizItem> _items = [];

  int lives;
  int index = 0;
  int score = 0;
  int combo = 0;
  int maxCombo = 0;
  int correct = 0;
  int answered = 0;
  int coinsEarned = 0;
  int timeLeft = 0;
  int totalTime = 0;
  bool finished = false;
  AnswerOutcome? outcome;
  final Set<int> removed = {};
  final Set<PowerUp> usedOnThisQuestion = {};
  Timer? _timer;

  QuizItem get item => _items[index];
  bool get isAnswered => outcome != null;
  int get totalQuestions => mode == GameMode.classic ? min(classicLength, _pool.length) : 0;

  /// Multiplicador do combo: 3 acertos = x1.5, 5 = x2, 8 = x3.
  static double multiplierFor(int combo) => combo >= 8
      ? 3
      : combo >= 5
      ? 2
      : combo >= 3
      ? 1.5
      : 1;

  double get multiplier => multiplierFor(combo);

  /// No modo Sobrevivência o tempo cai a cada 5 questões (mínimo de 15 s).
  int get _timeForCurrent {
    final base = item.seconds;
    if (mode == GameMode.classic) return base;
    return max(15, base - 4 * (answered ~/ 5));
  }

  void _refill() {
    final batch = [..._pool]..shuffle(_rng);
    // Evita repetir a mesma questão em seguida ao reembaralhar.
    if (_items.isNotEmpty && batch.length > 1 && batch.first.id == _items.last.question.id) {
      batch.add(batch.removeAt(0));
    }
    final take = mode == GameMode.classic ? batch.take(classicLength) : batch;
    _items.addAll([for (final q in take) QuizItem.shuffled(q, _rng)]);
  }

  void _startQuestion() {
    outcome = null;
    removed.clear();
    usedOnThisQuestion.clear();
    totalTime = _timeForCurrent;
    timeLeft = totalTime;
    _runTimer();
    notifyListeners();
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Avança o relógio em 1 segundo (chamado pelo timer; público para testes).
  void tick() {
    if (isAnswered || finished) return;
    if (timeLeft <= 1) {
      timeLeft = 0;
      answer(null);
    } else {
      timeLeft--;
      notifyListeners();
    }
  }

  /// Responde a alternativa mostrada na posição [choice]; `null` = tempo esgotado.
  AnswerOutcome? answer(int? choice) {
    if (isAnswered || finished) return null;
    if (choice != null && removed.contains(choice)) return null;
    _timer?.cancel();
    answered++;
    final isCorrect = choice != null && choice == item.correctIndex;
    var points = 0;
    var coins = 0;
    if (isCorrect) {
      combo++;
      maxCombo = max(maxCombo, combo);
      correct++;
      final timeBonus = 50 * timeLeft / totalTime;
      points = ((100 + timeBonus) * multiplier).round();
      coins = coinsPerCorrect + (combo % 3 == 0 ? 5 : 0);
      score += points;
      coinsEarned += coins;
    } else {
      combo = 0;
      lives--;
    }
    outcome = AnswerOutcome(
      selected: choice,
      correct: isCorrect,
      points: points,
      multiplier: multiplierFor(combo),
      coins: coins,
      timedOut: choice == null,
    );
    notifyListeners();
    return outcome;
  }

  bool get _isLastClassic => mode == GameMode.classic && index >= _items.length - 1;

  /// Vai para a próxima questão ou encerra a partida.
  void next() {
    if (!isAnswered || finished) return;
    if (lives <= 0 || _isLastClassic) {
      _finish();
      return;
    }
    index++;
    if (index >= _items.length) _refill();
    _startQuestion();
  }

  void _finish() {
    _timer?.cancel();
    finished = true;
    notifyListeners();
  }

  /// Encerra a partida antes do fim (ex.: o jogador saiu).
  void quit() => _finish();

  bool canUse(PowerUp p) => !isAnswered && !finished && !usedOnThisQuestion.contains(p);

  /// Aplica uma ajuda já paga. Devolve `false` se não puder ser usada agora.
  bool apply(PowerUp p) {
    if (!canUse(p)) return false;
    usedOnThisQuestion.add(p);
    switch (p) {
      case PowerUp.fiftyFifty:
        final wrong = [
          for (var i = 0; i < item.length; i++)
            if (i != item.correctIndex) i,
        ]..shuffle(_rng);
        removed.addAll(wrong.take(2));
      case PowerUp.extraTime:
        timeLeft += 15;
        totalTime += 15;
      case PowerUp.skip:
        _timer?.cancel();
        if (_isLastClassic) {
          _finish();
          return true;
        }
        index++;
        if (index >= _items.length) _refill();
        _startQuestion();
        return true;
    }
    notifyListeners();
    return true;
  }

  /// Estrelas do modo Clássico: 9+ acertos = 3, 7+ = 2, 5+ = 1.
  int get stars {
    if (mode == GameMode.survival) return correct >= 15 ? 3 : (correct >= 8 ? 2 : (correct >= 3 ? 1 : 0));
    if (lives <= 0) return 0;
    return correct >= 9 ? 3 : (correct >= 7 ? 2 : (correct >= 5 ? 1 : 0));
  }

  int get xpEarned => (score / 5).round() + correct * 10 + stars * 25;

  MatchSummary summary() => MatchSummary(
    mode: mode.id,
    score: score,
    correct: correct,
    answered: answered,
    maxCombo: maxCombo,
    xp: xpEarned,
    coins: coinsEarned + stars * 10,
    stars: stars,
  );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
