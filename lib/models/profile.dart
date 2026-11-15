/// Perfil do jogador guardado na nuvem (tabela `profiles`).
class Profile {
  const Profile({
    this.nome = '',
    this.turma,
    this.avatarPath,
    this.noRanking = true,
    this.pontos = 0,
    this.xp = 0,
    this.moedas = 100,
    this.respondidas = 0,
    this.acertos = 0,
    this.partidas = 0,
    this.melhorClassico = 0,
    this.melhorEstrelas = 0,
    this.melhorSobrevivencia = 0,
    this.melhorCombo = 0,
    this.diasSeguidos = 0,
    this.ultimoDiaJogado,
    this.niveisConcluidos = const {},
    this.bauDia,
    this.termosVersao,
    this.termosAceitosEm,
  });

  factory Profile.fromJson(Map<String, dynamic> j) {
    int n(String key, [int fallback = 0]) => (j[key] as num?)?.toInt() ?? fallback;
    return Profile(
      nome: (j['nome'] as String?) ?? '',
      turma: j['turma'] as String?,
      avatarPath: j['avatar_path'] as String?,
      noRanking: (j['no_ranking'] as bool?) ?? true,
      pontos: n('pontos'),
      xp: n('xp'),
      moedas: n('moedas', 100),
      respondidas: n('respondidas'),
      acertos: n('acertos'),
      partidas: n('partidas'),
      melhorClassico: n('melhor_classico'),
      melhorEstrelas: n('melhor_estrelas'),
      melhorSobrevivencia: n('melhor_sobrevivencia'),
      melhorCombo: n('melhor_combo'),
      diasSeguidos: n('dias_seguidos'),
      ultimoDiaJogado: j['ultimo_dia_jogado'] as String?,
      niveisConcluidos: {for (final n in (j['niveis_concluidos'] as List?) ?? const []) (n as num).toInt()},
      bauDia: j['bau_dia'] as String?,
      termosVersao: j['termos_versao'] as String?,
      termosAceitosEm: DateTime.tryParse((j['termos_aceitos_em'] as String?) ?? ''),
    );
  }

  final String nome;
  final String? turma;
  final String? avatarPath;
  final bool noRanking;
  final int pontos, xp, moedas, respondidas, acertos, partidas;
  final int melhorClassico, melhorEstrelas, melhorSobrevivencia, melhorCombo, diasSeguidos;

  /// Níveis concluídos (1 a 5 e 6 = casos clínicos), registrados pelo servidor.
  final Set<int> niveisConcluidos;

  /// Datas no formato `AAAA-MM-DD` (dia de Brasília, calculado no servidor).
  final String? ultimoDiaJogado, bauDia;
  final String? termosVersao;
  final DateTime? termosAceitosEm;

  /// Precisa aceitar a política (nunca aceitou ou aceitou uma versão antiga).
  bool needsConsent(String currentVersion) => termosAceitosEm == null || termosVersao != currentVersion;

  String get primeiroNome {
    final first = nome.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'Jogador' : first;
  }
}

class RankingEntry {
  const RankingEntry({
    required this.posicao,
    required this.nome,
    required this.pontos,
    required this.xp,
    this.turma,
    this.avatarPath,
    this.eu = false,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> j) => RankingEntry(
    posicao: (j['posicao'] as num).toInt(),
    nome: (j['nome'] as String?)?.trim().isNotEmpty == true ? j['nome'] as String : 'Jogador',
    turma: j['turma'] as String?,
    avatarPath: j['avatar_path'] as String?,
    pontos: (j['pontos'] as num).toInt(),
    xp: (j['xp'] as num?)?.toInt() ?? 0,
    eu: (j['eu'] as bool?) ?? false,
  );

  final int posicao, pontos, xp;
  final String nome;
  final String? turma, avatarPath;
  final bool eu;
}

/// Resultado de uma partida confirmado pelo servidor.
class MatchResult {
  const MatchResult({
    required this.stars,
    required this.xp,
    required this.coins,
    required this.score,
    required this.correct,
    required this.answered,
    required this.maxCombo,
    required this.newRecord,
    required this.streakIncreased,
    required this.profile,
  });

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
    stars: (j['estrelas'] as num).toInt(),
    xp: (j['xp'] as num).toInt(),
    coins: (j['moedas'] as num).toInt(),
    score: (j['pontos'] as num).toInt(),
    correct: (j['acertos'] as num).toInt(),
    answered: (j['respondidas'] as num).toInt(),
    maxCombo: (j['max_combo'] as num).toInt(),
    newRecord: (j['novo_recorde'] as bool?) ?? false,
    streakIncreased: (j['ofensiva_subiu'] as bool?) ?? false,
    profile: Profile.fromJson(j['perfil'] as Map<String, dynamic>),
  );

  final int stars, xp, coins, score, correct, answered, maxCombo;
  final bool newRecord, streakIncreased;
  final Profile profile;
}
