import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/game_backend.dart';
import '../models/profile.dart';

/// Resultado de uma partida, usado para atualizar o progresso do jogador.
class MatchSummary {
  const MatchSummary({
    required this.mode,
    required this.score,
    required this.correct,
    required this.answered,
    required this.maxCombo,
    required this.xp,
    required this.coins,
    required this.stars,
  });

  final String mode;
  final int score, correct, answered, maxCombo, xp, coins, stars;
}

/// O que mudou depois de registrar uma partida (para as animações do resultado).
class ProgressChange {
  const ProgressChange({
    required this.levelBefore,
    required this.levelAfter,
    required this.newRecord,
    required this.streakDays,
    required this.streakIncreased,
    this.confirmed,
    this.syncFailed = false,
  });

  final int levelBefore, levelAfter, streakDays;
  final bool newRecord, streakIncreased;

  /// Resultado conferido pelo servidor (com conta). Prevalece sobre o do aparelho.
  final MatchSummary? confirmed;

  /// Com conta, mas o servidor não respondeu: o resultado não foi salvo.
  final bool syncFailed;

  bool get leveledUp => levelAfter > levelBefore;
}

/// Progresso do jogador (nível, XP, moedas, recordes e ofensiva diária).
///
/// Sem conta, fica salvo só no aparelho. Com conta ([attach] com um
/// [GameBackend]), vem do servidor, que é quem confere as respostas e calcula
/// pontos, moedas, XP e estrelas. Cada conta tem o próprio progresso.
class PlayerStore extends ChangeNotifier {
  PlayerStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const startingCoins = 100;
  static const chestCoins = 50;

  static const titles = [
    'Calouro',
    'Estagiário',
    'Plantonista',
    'Residente',
    'Especialista',
    'Radiologista',
    'Mestre da TC',
    'Lenda do Hounsfield',
  ];

  final DateTime Function() _clock;

  int xp = 0;
  int coins = startingCoins;
  int totalScore = 0;
  int bestClassicScore = 0;
  int bestClassicStars = 0;
  int bestSurvival = 0;
  int bestCombo = 0;
  int totalCorrect = 0;
  int totalAnswered = 0;
  int matches = 0;
  int streakDays = 0;
  String? _lastPlayDay;
  String? _lastChestDay;

  // ---------------------------------------------------------------------------
  // Conta
  // ---------------------------------------------------------------------------
  GameBackend? _remote;
  Profile? _profile;

  GameBackend? get remote => _remote;
  bool get isOnline => _remote != null;

  /// Perfil do jogador logado (nome, turma, foto). `null` no modo sem conta.
  Profile? get profile => _profile;
  String? get avatarUrl => _remote?.avatarUrl(_profile?.avatarPath);

  /// Liga ([backend] não nulo) ou desliga a sincronização com a conta.
  Future<void> attach(GameBackend? backend) async {
    _remote = backend;
    _profile = null;
    _matchId = null;
    _pending = Future.value();
    if (backend == null) {
      await load();
      return;
    }
    _applyProfile(const Profile());
    try {
      _applyProfile(await backend.fetchMine());
    } on BackendFailure {
      // Sem conexão: mostra o que tiver e tenta de novo na próxima ação.
    }
  }

  Future<void> refresh() async {
    final remote = _remote;
    if (remote != null) _applyProfile(await remote.fetchMine());
  }

  void _applyProfile(Profile p) {
    if (_remote == null) return;
    _profile = p;
    xp = p.xp;
    coins = p.moedas;
    totalScore = p.pontos;
    bestClassicScore = p.melhorClassico;
    bestClassicStars = p.melhorEstrelas;
    bestSurvival = p.melhorSobrevivencia;
    bestCombo = p.melhorCombo;
    totalCorrect = p.acertos;
    totalAnswered = p.respondidas;
    matches = p.partidas;
    streakDays = p.diasSeguidos;
    _lastPlayDay = p.ultimoDiaJogado;
    _lastChestDay = p.bauDia;
    notifyListeners();
  }

  /// Logado, com perfil carregado, mas sem ter aceitado a versão atual da política.
  bool needsConsent(String version) => _profile?.needsConsent(version) ?? false;

  Future<void> acceptTerms(String version) async => _applyProfile(await _requireRemote().acceptTerms(version));

  Future<void> saveProfile({required String nome, String? turma, required bool noRanking}) async =>
      _applyProfile(await _requireRemote().update(nome: nome, turma: turma, noRanking: noRanking));

  Future<void> changeAvatar(Uint8List bytes, String mimeType) async =>
      _applyProfile(await _requireRemote().uploadAvatar(bytes, mimeType));

  Future<Map<String, dynamic>> myData() => _requireRemote().myData();

  /// Apaga a conta; depois disso o app volta para a tela de login.
  Future<void> deleteAccount() => _requireRemote().deleteAccount();

  GameBackend _requireRemote() => _remote ?? (throw const BackendFailure('Entre na sua conta para usar essa função.'));

  // ---------------------------------------------------------------------------
  // Níveis, ofensiva e baú
  // ---------------------------------------------------------------------------

  /// XP total necessário para chegar ao nível [n] (nível 1 = 0 XP).
  static int xpForLevel(int n) => 100 * n * (n - 1);

  static int levelFor(int xp) {
    var n = 1;
    while (xp >= xpForLevel(n + 1)) {
      n++;
    }
    return n;
  }

  static String titleFor(int level) => titles[(level - 1).clamp(0, titles.length - 1)];

  int get level => levelFor(xp);

  String get title => titleFor(level);

  /// Progresso (0 a 1) dentro do nível atual.
  double get levelProgress {
    final start = xpForLevel(level);
    final end = xpForLevel(level + 1);
    return (xp - start) / (end - start);
  }

  int get xpToNextLevel => xpForLevel(level + 1) - xp;

  double get accuracy => totalAnswered == 0 ? 0 : totalCorrect / totalAnswered;

  String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String get _today => _day(_clock());
  String get _yesterday => _day(_clock().subtract(const Duration(days: 1)));

  bool get chestAvailable => _lastChestDay != _today;

  /// A ofensiva só conta se o jogador jogou hoje ou ontem.
  int get activeStreak => (_lastPlayDay == _today || _lastPlayDay == _yesterday) ? streakDays : 0;

  bool get playedToday => _lastPlayDay == _today;

  // ---------------------------------------------------------------------------
  // Modo sem conta (salvo no aparelho)
  // ---------------------------------------------------------------------------
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    xp = p.getInt('xp') ?? 0;
    coins = p.getInt('coins') ?? startingCoins;
    totalScore = p.getInt('totalScore') ?? 0;
    bestClassicScore = p.getInt('bestClassicScore') ?? 0;
    bestClassicStars = p.getInt('bestClassicStars') ?? 0;
    bestSurvival = p.getInt('bestSurvival') ?? 0;
    bestCombo = p.getInt('bestCombo') ?? 0;
    totalCorrect = p.getInt('totalCorrect') ?? 0;
    totalAnswered = p.getInt('totalAnswered') ?? 0;
    matches = p.getInt('matches') ?? 0;
    streakDays = p.getInt('streakDays') ?? 0;
    _lastPlayDay = p.getString('lastPlayDay');
    _lastChestDay = p.getString('lastChestDay');
    notifyListeners();
  }

  Future<void> _save() async {
    if (isOnline) return;
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setInt('xp', xp),
      p.setInt('coins', coins),
      p.setInt('totalScore', totalScore),
      p.setInt('bestClassicScore', bestClassicScore),
      p.setInt('bestClassicStars', bestClassicStars),
      p.setInt('bestSurvival', bestSurvival),
      p.setInt('bestCombo', bestCombo),
      p.setInt('totalCorrect', totalCorrect),
      p.setInt('totalAnswered', totalAnswered),
      p.setInt('matches', matches),
      p.setInt('streakDays', streakDays),
      if (_lastPlayDay != null) p.setString('lastPlayDay', _lastPlayDay!),
      if (_lastChestDay != null) p.setString('lastChestDay', _lastChestDay!),
    ]);
  }

  /// Gasta moedas no aparelho. Devolve `false` se não houver saldo.
  Future<bool> spend(int amount) async {
    if (coins < amount) return false;
    coins -= amount;
    notifyListeners();
    await _save();
    return true;
  }

  /// Abre o baú diário. Devolve as moedas ganhas (0 se já abriu hoje).
  Future<int> openChest() async {
    if (!chestAvailable) return 0;
    final remote = _remote;
    if (remote != null) {
      final (won, profile) = await remote.openChest();
      _applyProfile(profile);
      return won;
    }
    _lastChestDay = _today;
    coins += chestCoins;
    notifyListeners();
    await _save();
    return chestCoins;
  }

  // ---------------------------------------------------------------------------
  // Partida
  // ---------------------------------------------------------------------------
  Future<String>? _matchId;

  /// Chamadas ao servidor da partida atual, sempre na ordem em que aconteceram.
  Future<void> _pending = Future.value();

  void _enqueue(Future<void> Function(GameBackend remote, String matchId) action) {
    final remote = _remote;
    final match = _matchId;
    if (remote == null || match == null) return;
    _pending = _pending.then((_) async {
      try {
        await action(remote, await match);
      } on BackendFailure {
        // O servidor é a referência: os números são corrigidos ao fim da partida.
      }
    });
  }

  /// Avisa o início de uma partida (com conta, abre a partida no servidor).
  void beginMatch(String mode) {
    final remote = _remote;
    if (remote == null) return;
    final id = remote.startMatch(mode);
    _matchId = id;
    // Evita erro "não tratado" se a abertura falhar; quem espera trata.
    unawaited(id.then<void>((_) {}, onError: (_) {}));
  }

  /// Registra no servidor a alternativa marcada (índice original; `null` = tempo esgotado).
  void reportAnswer({
    required int questionId,
    required int? alternative,
    required int timeLeft,
    required int totalTime,
  }) => _enqueue((remote, id) async {
    _applyProfile(
      await remote.answer(
        matchId: id,
        questionId: questionId,
        alternative: alternative,
        timeLeft: timeLeft,
        totalTime: totalTime,
      ),
    );
  });

  /// Paga uma ajuda. Devolve `false` se não houver moedas.
  Future<bool> buyPowerUp({required String powerUp, required int cost, required int questionId}) async {
    if (!isOnline) return spend(cost);
    if (coins < cost) return false;
    coins -= cost;
    notifyListeners();
    _enqueue((remote, id) async {
      try {
        _applyProfile(await remote.usePowerUp(matchId: id, powerUp: powerUp, questionId: questionId));
      } on BackendFailure {
        unawaited(refresh().catchError((_) {}));
      }
    });
    return true;
  }

  Future<ProgressChange> recordMatch(MatchSummary m) async {
    final levelBefore = level;
    final remote = _remote;
    final match = _matchId;
    if (remote != null) {
      _matchId = null;
      try {
        await _pending;
        if (match == null) throw const BackendFailure('Partida não registrada.');
        final r = await remote.finishMatch(await match);
        _applyProfile(r.profile);
        return ProgressChange(
          levelBefore: levelBefore,
          levelAfter: level,
          newRecord: r.newRecord,
          streakDays: streakDays,
          streakIncreased: r.streakIncreased,
          confirmed: MatchSummary(
            mode: m.mode,
            score: r.score,
            correct: r.correct,
            answered: r.answered,
            maxCombo: r.maxCombo,
            xp: r.xp,
            coins: r.coins,
            stars: r.stars,
          ),
        );
      } catch (_) {
        unawaited(refresh().catchError((_) {}));
        return ProgressChange(
          levelBefore: levelBefore,
          levelAfter: levelBefore,
          newRecord: false,
          streakDays: activeStreak,
          streakIncreased: false,
          syncFailed: true,
        );
      }
    }

    xp += m.xp;
    coins += m.coins;
    totalScore += m.score;
    totalCorrect += m.correct;
    totalAnswered += m.answered;
    matches++;
    if (m.maxCombo > bestCombo) bestCombo = m.maxCombo;

    var newRecord = false;
    if (m.mode == 'survival') {
      if (m.correct > bestSurvival) {
        bestSurvival = m.correct;
        newRecord = true;
      }
    } else {
      if (m.score > bestClassicScore) {
        bestClassicScore = m.score;
        newRecord = true;
      }
      if (m.stars > bestClassicStars) bestClassicStars = m.stars;
    }

    var streakIncreased = false;
    if (m.answered > 0 && _lastPlayDay != _today) {
      streakDays = _lastPlayDay == _yesterday ? streakDays + 1 : 1;
      _lastPlayDay = _today;
      streakIncreased = true;
    }

    notifyListeners();
    await _save();
    return ProgressChange(
      levelBefore: levelBefore,
      levelAfter: level,
      newRecord: newRecord,
      streakDays: streakDays,
      streakIncreased: streakIncreased,
    );
  }
}

class PlayerScope extends InheritedNotifier<PlayerStore> {
  const PlayerScope({super.key, required PlayerStore store, required super.child}) : super(notifier: store);

  static PlayerStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PlayerScope>()!.notifier!;

  static PlayerStore read(BuildContext context) => context.getInheritedWidgetOfExactType<PlayerScope>()!.notifier!;
}
