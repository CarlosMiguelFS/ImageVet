import 'package:flutter/material.dart';

import '../models/question.dart';
import '../state/game_controller.dart';
import '../state/player_store.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti.dart';
import '../widgets/emoji.dart';
import '../widgets/ui.dart';
import 'game_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.mode,
    required this.summary,
    required this.change,
    required this.livesLeft,
    required this.questions,
    this.practice = false,
  });

  final GameMode mode;
  final MatchSummary summary;
  final ProgressChange change;
  final int livesLeft;
  final List<Question> questions;

  /// Partida de teste: os pontos aparecem, mas não entram no perfil nem no ranking.
  final bool practice;

  String get _headline {
    if (mode == GameMode.survival) {
      return change.newRecord ? 'Novo [mint:recorde]!' : 'Fim da [brand:sobrevivência]';
    }
    if (livesLeft <= 0) return 'Acabaram as [coral:vidas]';
    return switch (summary.stars) {
      3 => 'Perfeito, [mint:3 estrelas]!',
      2 => 'Mandou [brand:muito bem]!',
      1 => 'Fase [amber:concluída]',
      _ => 'Bora [clay:de novo]?',
    };
  }

  String get _subtitle {
    if (mode == GameMode.survival) {
      return 'Você acertou ${summary.correct} ${summary.correct == 1 ? 'questão' : 'questões'} antes de perder as 3 vidas.';
    }
    if (livesLeft <= 0) {
      return practice
          ? 'Revise as explicações e tente de novo.'
          : 'Revise as explicações e tente de novo: cada partida embaralha as alternativas.';
    }
    return 'Você acertou ${summary.correct} de ${summary.answered} questões de tomografia.';
  }

  @override
  Widget build(BuildContext context) {
    final store = PlayerScope.of(context);
    final celebrate = summary.stars >= 2 || change.newRecord || change.leveledUp || change.stagePassed != null;
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 36),
              children: [
                ResponsiveBody(
                  maxWidth: 640,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Stars(stars: summary.stars),
                      const SizedBox(height: 22),
                      Headline(_headline, size: context.isPhone ? 32 : 42, textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      Text(_subtitle, textAlign: TextAlign.center, style: mutedText),
                      if (practice) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Partida de teste: estes pontos não contam para o seu perfil nem para o ranking. '
                          'Escolha um nível na tela inicial para valer pontos!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.mintInk, fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                      ],
                      if (change.syncFailed) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Sem conexão com o servidor: esta partida não entrou no seu perfil nem no ranking.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.coralInk, fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                      ],
                      if (change.stagePassed case final stage?) ...[
                        const SizedBox(height: 20),
                        _StageUnlocked(stage: stage),
                      ],
                      if (change.leveledUp) ...[
                        const SizedBox(height: 20),
                        _LevelUp(level: change.levelAfter, title: store.title),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _Stat(emoji: '⭐', value: '${summary.score}', label: 'Pontos'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Stat(emoji: '🎯', value: '${summary.correct}', label: 'Acertos'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Stat(emoji: '🔥', value: 'x${summary.maxCombo}', label: 'Maior combo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!practice)
                        SoftCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    'Nível ${store.level} · ${store.title}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                                  StatPill(emoji: '✨', value: '+${summary.xp} XP'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              RoundedProgress(value: store.levelProgress, height: 12),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  StatPill(
                                    emoji: '💎',
                                    value: '+${summary.coins}',
                                    tone: Tone.stone,
                                    tooltip: 'Moedas ganhas',
                                  ),
                                  if (change.newRecord)
                                    const StatPill(emoji: '🏆', value: 'Novo recorde', tone: Tone.amber),
                                  if (change.streakIncreased)
                                    StatPill(
                                      emoji: '🔥',
                                      value: '${change.streakDays} ${change.streakDays == 1 ? 'dia' : 'dias'} seguidos',
                                      tone: Tone.clay,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 28),
                      PillButton(
                        label: 'Jogar de novo',
                        icon: Icons.replay_rounded,
                        big: true,
                        expand: true,
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => GameScreen(mode: mode, questions: questions, practice: practice),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PillButton(
                        label: 'Voltar ao início',
                        kind: ButtonStyleKind.outline,
                        expand: true,
                        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (celebrate) const Positioned.fill(child: Confetti()),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (var i = 0; i < 3; i++)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 500 + i * 300),
          curve: Interval(i * 0.3, 1, curve: Curves.elasticOut),
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: Padding(
            padding: EdgeInsets.only(left: 6, right: 6, bottom: i == 1 ? 18 : 0),
            child: Opacity(
              opacity: i < stars ? 1 : 0.22,
              child: Emoji('⭐', size: i == 1 ? 76 : 58),
            ),
          ),
        ),
    ],
  );
}

class _LevelUp extends StatelessWidget {
  const _LevelUp({required this.level, required this.title});

  final int level;
  final String title;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 900),
    curve: Curves.elasticOut,
    builder: (context, v, child) => Transform.scale(scale: v, child: child),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.brand500, AppColors.brand700]),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.glow,
      ),
      child: Row(
        children: [
          const Emoji('🚀', size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SUBIU DE NÍVEL!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Nível $level · $title',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.emoji, required this.value, required this.label});

  final String emoji, value, label;

  @override
  Widget build(BuildContext context) => SoftCard(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
    child: Column(
      children: [
        Emoji(emoji, size: 25),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

/// Aviso de nível concluído e do que foi liberado.
class _StageUnlocked extends StatelessWidget {
  const _StageUnlocked({required this.stage});

  final int stage;

  String get _message => switch (stage) {
    PlayerStore.finalStage => 'Você venceu a fase final dos casos clínicos. Parabéns!',
    5 => 'Nível 5 concluído! Os casos clínicos foram liberados.',
    _ => 'Nível $stage concluído! O nível ${stage + 1} foi liberado.',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(AppRadius.xl)),
    child: Row(
      children: [
        const Emoji('🎉', size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _message,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.mintInk),
          ),
        ),
      ],
    ),
  );
}
