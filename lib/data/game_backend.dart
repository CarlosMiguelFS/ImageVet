import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// Erro de perfil, partida ou ranking já traduzido para mostrar ao jogador.
class BackendFailure implements Exception {
  const BackendFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Tudo o que o jogo guarda na nuvem. Quem calcula pontos, moedas, XP e
/// estrelas é o servidor: o app só informa o que o jogador fez.
abstract class GameBackend {
  static const maxAvatarBytes = 2 * 1024 * 1024;
  static const avatarTypes = {'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp'};

  Future<Profile> fetchMine();
  Future<Profile> update({required String nome, String? turma, required bool noRanking});
  Future<Profile> uploadAvatar(Uint8List bytes, String mimeType);
  String? avatarUrl(String? path);

  /// Abre uma partida no servidor e devolve o id dela.
  Future<String> startMatch(String mode);

  /// Envia a alternativa marcada (índice original; `null` = tempo esgotado).
  Future<Profile> answer({
    required String matchId,
    required int questionId,
    required int? alternative,
    required int timeLeft,
    required int totalTime,
  });

  /// Desconta as moedas da ajuda (`fiftyFifty`, `extraTime` ou `skip`).
  Future<Profile> usePowerUp({required String matchId, required String powerUp, required int questionId});
  Future<MatchResult> finishMatch(String matchId);

  /// Abre o baú diário; devolve as moedas ganhas (0 se já abriu hoje) e o perfil.
  Future<(int, Profile)> openChest();

  /// Ranking `geral` ou da `semana`.
  Future<List<RankingEntry>> ranking({String period = 'geral', int limit = 50});

  /// LGPD: registra o aceite da Política de Privacidade.
  Future<Profile> acceptTerms(String version);

  /// LGPD: tudo o que está guardado sobre o jogador.
  Future<Map<String, dynamic>> myData();

  /// LGPD: apaga foto, partidas, respostas, perfil e a conta.
  Future<void> deleteAccount();
}

class SupabaseGameBackend implements GameBackend {
  static const _bucket = 'avatars';

  SupabaseClient get _db => Supabase.instance.client;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const BackendFailure('Sua sessão expirou. Entre de novo.');
    return id;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on BackendFailure {
      rethrow;
    } on PostgrestException catch (e) {
      throw BackendFailure(switch (e.code) {
        '54000' => 'Calma! Muitas ações seguidas. Tente de novo em instantes.',
        '42501' => 'Aceite a Política de Privacidade para salvar seu progresso.',
        'P0001' => 'Moedas insuficientes.',
        '22023' => 'Essa jogada não pôde ser registrada.',
        '23514' => 'Algum campo tem caracteres ou tamanho não permitidos.',
        _ => 'Não foi possível falar com o servidor. Tente de novo em instantes.',
      });
    } on StorageException {
      throw const BackendFailure('Não foi possível enviar a foto. Use JPG, PNG ou WEBP de até 2 MB.');
    } catch (_) {
      throw const BackendFailure('Sem conexão com o servidor. Verifique sua internet.');
    }
  }

  Future<T> _rpc<T>(String fn, [Map<String, dynamic>? params]) => _db.rpc<T>(fn, params: params);

  @override
  Future<Profile> fetchMine() => _guard(() async {
    final row = await _db.from('profiles').select().eq('id', _uid).single();
    return Profile.fromJson(row);
  });

  @override
  Future<Profile> update({required String nome, String? turma, required bool noRanking}) => _guard(() async {
    final cleanTurma = turma?.trim();
    final row = await _db
        .from('profiles')
        .update({
          'nome': nome.trim(),
          'turma': (cleanTurma == null || cleanTurma.isEmpty) ? null : cleanTurma,
          'no_ranking': noRanking,
        })
        .eq('id', _uid)
        .select()
        .single();
    return Profile.fromJson(row);
  });

  @override
  Future<Profile> uploadAvatar(Uint8List bytes, String mimeType) => _guard(() async {
    final ext = GameBackend.avatarTypes[mimeType];
    if (ext == null) throw const BackendFailure('Use uma foto JPG, PNG ou WEBP.');
    if (bytes.length > GameBackend.maxAvatarBytes) {
      throw const BackendFailure('A foto passou de 2 MB. Escolha uma imagem menor.');
    }
    final uid = _uid;
    final previous = (await fetchMine()).avatarPath;
    // Nome novo a cada envio evita foto antiga presa no cache do navegador.
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, cacheControl: '31536000'),
        );
    final row = await _db.from('profiles').update({'avatar_path': path}).eq('id', uid).select().single();
    if (previous != null && previous != path) {
      try {
        await _db.storage.from(_bucket).remove([previous]);
      } catch (_) {
        // A foto antiga sobrando não atrapalha o uso.
      }
    }
    return Profile.fromJson(row);
  });

  @override
  String? avatarUrl(String? path) => path == null ? null : _db.storage.from(_bucket).getPublicUrl(path);

  @override
  Future<String> startMatch(String mode) => _guard(() => _rpc<String>('iniciar_partida', {'p_modo': mode}));

  @override
  Future<Profile> answer({
    required String matchId,
    required int questionId,
    required int? alternative,
    required int timeLeft,
    required int totalTime,
  }) => _guard(() async {
    final res = await _rpc<Map<String, dynamic>>('responder', {
      'p_partida': matchId,
      'p_questao_id': questionId,
      'p_alternativa': alternative,
      'p_tempo_restante': timeLeft,
      'p_tempo_total': totalTime,
    });
    return Profile.fromJson(res['perfil'] as Map<String, dynamic>);
  });

  @override
  Future<Profile> usePowerUp({required String matchId, required String powerUp, required int questionId}) =>
      _guard(() async {
        final row = await _rpc<Map<String, dynamic>>('usar_ajuda', {
          'p_partida': matchId,
          'p_ajuda': powerUp,
          'p_questao_id': questionId,
        });
        return Profile.fromJson(row);
      });

  @override
  Future<MatchResult> finishMatch(String matchId) => _guard(() async {
    final res = await _rpc<Map<String, dynamic>>('finalizar_partida', {'p_partida': matchId});
    return MatchResult.fromJson(res);
  });

  @override
  Future<(int, Profile)> openChest() => _guard(() async {
    final res = await _rpc<Map<String, dynamic>>('abrir_bau');
    return ((res['ganhou'] as num).toInt(), Profile.fromJson(res['perfil'] as Map<String, dynamic>));
  });

  @override
  Future<List<RankingEntry>> ranking({String period = 'geral', int limit = 50}) => _guard(() async {
    final rows = await _rpc<List<dynamic>>('ranking', {'p_periodo': period, 'p_limite': limit});
    return [for (final r in rows) RankingEntry.fromJson(r as Map<String, dynamic>)];
  });

  @override
  Future<Profile> acceptTerms(String version) => _guard(() async {
    final row = await _rpc<Map<String, dynamic>>('aceitar_termos', {'p_versao': version});
    return Profile.fromJson(row);
  });

  @override
  Future<Map<String, dynamic>> myData() => _guard(() => _rpc<Map<String, dynamic>>('meus_dados'));

  @override
  Future<void> deleteAccount() => _guard(() async {
    final uid = _uid;
    // Fotos saem pelo Storage (o banco não deixa apagar arquivos direto).
    final files = await _db.storage.from(_bucket).list(path: uid);
    if (files.isNotEmpty) {
      await _db.storage.from(_bucket).remove([for (final f in files) '$uid/${f.name}']);
    }
    await _rpc<void>('excluir_minha_conta');
    try {
      await _db.auth.signOut();
    } catch (_) {
      // A conta já não existe; a sessão local é limpa mesmo assim.
    }
  });
}
