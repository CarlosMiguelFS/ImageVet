import 'dart:typed_data';

import 'package:imagivet/data/game_backend.dart';
import 'package:imagivet/models/profile.dart';
import 'package:imagivet/state/auth_service.dart';

/// Login falso: começa no estado pedido e troca de estado sem rede.
class FakeAuth extends AuthService {
  FakeAuth([this._status = AuthStatus.signedOut]);

  AuthStatus _status;
  final calls = <String>[];

  @override
  bool get isAvailable => true;
  @override
  AuthStatus get status => _status;
  @override
  AppUser? get user => _status == AuthStatus.signedIn ? const AppUser(email: 'ana@exemplo.com', name: 'Ana') : null;

  void _set(AuthStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  Future<void> init() async {}
  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    if (password != 'senha123') throw const AuthFailure('E-mail ou senha incorretos.');
    _set(AuthStatus.signedIn);
  }

  @override
  Future<SignUpResult> signUp({required String name, required String email, required String password}) async {
    calls.add('signUp:$email');
    return SignUpResult.confirmEmail;
  }

  @override
  Future<void> signInWithGoogle() async => calls.add('google');
  @override
  Future<bool> emailExists(String email) async => email == 'ana@exemplo.com';
  @override
  Future<void> sendPasswordReset(String email) async => calls.add('reset:$email');
  @override
  Future<void> updatePassword(String password) async => _set(AuthStatus.signedIn);
  @override
  Future<void> signOut() async => _set(AuthStatus.signedOut);
  @override
  Future<void> continueAsGuest() async => _set(AuthStatus.guest);
  @override
  Future<void> leaveGuestMode() async => _set(AuthStatus.signedOut);
}

/// Servidor falso que registra o que o app enviou.
class FakeBackend implements GameBackend {
  FakeBackend({this.profile = const Profile(nome: 'Ana Souza', moedas: 100, termosVersao: 'x')});

  Profile profile;
  final answers = <(int questionId, int? alternative)>[];
  final powerUps = <String>[];
  final modes = <String>[];
  int finished = 0;

  Profile _with({int? moedas, int? xp, int? pontos, String? versao, DateTime? aceito}) => Profile(
    nome: profile.nome,
    turma: profile.turma,
    moedas: moedas ?? profile.moedas,
    xp: xp ?? profile.xp,
    pontos: pontos ?? profile.pontos,
    termosVersao: versao ?? profile.termosVersao,
    termosAceitosEm: aceito ?? profile.termosAceitosEm,
  );

  @override
  Future<Profile> fetchMine() async => profile;
  @override
  Future<Profile> update({required String nome, String? turma, required bool noRanking}) async => profile;
  @override
  Future<Profile> uploadAvatar(Uint8List bytes, String mimeType) async => profile;
  @override
  String? avatarUrl(String? path) => null;

  @override
  Future<String> startMatch(String mode) async {
    modes.add(mode);
    return 'partida-1';
  }

  @override
  Future<Profile> answer({
    required String matchId,
    required int questionId,
    required int? alternative,
    required int timeLeft,
    required int totalTime,
  }) async {
    answers.add((questionId, alternative));
    return profile;
  }

  @override
  Future<Profile> usePowerUp({required String matchId, required String powerUp, required int questionId}) async {
    powerUps.add(powerUp);
    return profile = _with(moedas: profile.moedas - 30);
  }

  @override
  Future<MatchResult> finishMatch(String matchId) async {
    finished++;
    profile = _with(xp: profile.xp + 500, pontos: profile.pontos + 999);
    return MatchResult(
      stars: 2,
      xp: 500,
      coins: 40,
      score: 999,
      correct: 7,
      answered: 10,
      maxCombo: 4,
      newRecord: true,
      streakIncreased: true,
      profile: profile,
    );
  }

  @override
  Future<(int, Profile)> openChest() async => (50, profile = _with(moedas: profile.moedas + 50));

  @override
  Future<List<RankingEntry>> ranking({String period = 'geral', int limit = 50}) async => const [
    RankingEntry(posicao: 1, nome: 'Bruno Lima', pontos: 4200, xp: 2500, turma: '5º período'),
    RankingEntry(posicao: 2, nome: 'Ana Souza', pontos: 3100, xp: 900, eu: true),
  ];

  @override
  Future<Profile> acceptTerms(String version) async => profile = _with(versao: version, aceito: DateTime(2026, 11, 12));
  @override
  Future<Map<String, dynamic>> myData() async => {'perfil': profile.nome};
  @override
  Future<void> deleteAccount() async {}
}
