import 'dart:async';

import 'package:flutter/material.dart';

import '../data/game_backend.dart';
import '../models/question.dart';
import '../state/auth_service.dart';
import '../state/game_controller.dart';
import '../state/player_store.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti.dart';
import '../widgets/ui.dart';
import 'game_screen.dart';
import 'profile_screen.dart';
import 'ranking_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.questions});

  final List<Question> questions;

  /// Abre uma partida; [set] limita o Clássico a um dos bancos (a Sobrevivência usa todos).
  void _play(BuildContext context, GameMode mode, [QuestionSet? set]) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GameScreen(
        mode: mode,
        questions: set == null
            ? questions
            : [
                for (final q in questions)
                  if (q.set == set) q,
              ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = PlayerScope.of(context);
    final wide = context.screenWidth >= 980;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          FloatingNav(
            leading: const BrandMark(),
            trailing: [
              if (!context.isPhone)
                StatPill(
                  emoji: '🔥',
                  value: '${store.activeStreak}',
                  tone: Tone.clay,
                  tooltip: 'Ofensiva: dias seguidos jogando',
                ),
              StatPill(emoji: '💎', value: '${store.coins}', tooltip: 'Moedas'),
              if (!context.isPhone) _LevelChip(level: store.level),
              RoundIconButton(
                icon: Icons.emoji_events_outlined,
                tooltip: 'Ranking',
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RankingScreen())),
              ),
              const _AccountButton(),
            ],
          ),
          SizedBox(height: context.isPhone ? 28 : 56),
          ResponsiveBody(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _Hero(onPlay: () => _play(context, GameMode.classic, QuestionSet.principais)),
                      ),
                      const SizedBox(width: 48),
                      const Expanded(flex: 4, child: _PlayerCard()),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(onPlay: () => _play(context, GameMode.classic, QuestionSet.principais)),
                      const SizedBox(height: 28),
                      const _PlayerCard(),
                    ],
                  ),
          ),
          SizedBox(height: context.isPhone ? 48 : 80),
          ResponsiveBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Eyebrow('Modos de jogo'),
                const SizedBox(height: 10),
                Headline('Escolha como [brand:jogar]', size: context.isPhone ? 30 : 40),
                const SizedBox(height: 24),
                _Grid(
                  children: [
                    _ModeCard(
                      emoji: '🩻',
                      title: QuestionSet.principais.label,
                      description: 'As 10 perguntas essenciais de tomografia: 3 vidas, até 3 estrelas e combos.',
                      tags: const ['10 fases', '3 vidas'],
                      tone: Tone.brand,
                      onTap: () => _play(context, GameMode.classic, QuestionSet.principais),
                    ),
                    _ModeCard(
                      emoji: '🐾',
                      title: QuestionSet.casos.label,
                      description: '10 casos da rotina veterinária: leia o cenário e escolha a melhor conduta.',
                      tags: const ['10 casos', '3 vidas'],
                      tone: Tone.mint,
                      onTap: () => _play(context, GameMode.classic, QuestionSet.casos),
                    ),
                    _ModeCard(
                      emoji: '♾️',
                      title: 'Sobrevivência',
                      description: 'Mistura as 20 questões sem fim. O tempo diminui a cada 5 respostas.',
                      tags: ['Até errar 3', 'Recorde: ${store.bestSurvival}'],
                      tone: Tone.clay,
                      onTap: () => _play(context, GameMode.survival),
                    ),
                  ],
                ),
                SizedBox(height: context.isPhone ? 48 : 72),
                const Eyebrow('Recompensas'),
                const SizedBox(height: 10),
                Headline('Volte todo dia, ganhe [amber:mais]', size: context.isPhone ? 30 : 40),
                const SizedBox(height: 24),
                const _Grid(children: [_ChestCard(), _StreakCard(), _PowerUpsCard()]),
                SizedBox(height: context.isPhone ? 48 : 72),
                const Eyebrow('Conquistas'),
                const SizedBox(height: 10),
                Headline('Colecione [stone:medalhas]', size: context.isPhone ? 30 : 40),
                const SizedBox(height: 24),
                const _Achievements(),
                const SizedBox(height: 56),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Feito por '),
                      TextSpan(
                        text: 'Carlos Miguel Fernandes dos Santos',
                        style: TextStyle(color: AppColors.brand600, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto do jogador (abre o perfil) ou botão de entrar, no modo sem conta.
class _AccountButton extends StatelessWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context) {
    final store = PlayerScope.of(context);
    final auth = AuthScope.of(context);
    final profile = store.profile;
    if (store.isOnline) {
      return Tooltip(
        message: 'Meu perfil',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
          child: UserAvatar(name: profile?.nome ?? '', url: store.avatarUrl, size: 40),
        ),
      );
    }
    if (!auth.isAvailable) return const SizedBox.shrink();
    if (context.isPhone) {
      return RoundIconButton(
        icon: Icons.login_rounded,
        tooltip: 'Entrar',
        onPressed: () => AuthScope.read(context).leaveGuestMode(),
      );
    }
    return PillButton(
      label: 'Entrar',
      kind: ButtonStyleKind.dark,
      onPressed: () => AuthScope.read(context).leaveGuestMode(),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.pill)),
    child: Text(
      'Nível $level',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Headline('Eu quero dominar [brand:tomografia] jogando, sem [clay:decoreba]'),
      const SizedBox(height: 18),
      Text.rich(
        const TextSpan(
          children: [
            TextSpan(text: 'Perguntas e casos clínicos de TC veterinária com '),
            TextSpan(
              text: 'vidas, combos e recompensas',
              style: TextStyle(color: AppColors.brand600, fontWeight: FontWeight.w700),
            ),
            TextSpan(text: '. Cada acerto vale XP, moedas e sobe você de nível.'),
          ],
        ),
        style: mutedText.copyWith(fontSize: context.isPhone ? 16 : 18),
      ),
      const SizedBox(height: 26),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          PillButton(label: 'Jogar agora', icon: Icons.arrow_forward_rounded, big: true, onPressed: onPlay),
          PillButton(
            label: 'Como funciona',
            kind: ButtonStyleKind.outline,
            big: true,
            onPressed: () => _showHowToPlay(context),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Grátis. ',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            TextSpan(text: 'Partidas de 5 minutos.'),
          ],
        ),
        style: TextStyle(fontSize: 13.5, color: AppColors.inkMuted),
      ),
    ],
  );
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard();

  @override
  Widget build(BuildContext context) {
    final store = PlayerScope.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand200, AppColors.brand100],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl + 6),
      ),
      child: SoftCard(
        radius: AppRadius.xxl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _LevelRing(level: store.level, progress: store.levelProgress),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Faltam ${store.xpToNextLevel} XP para o nível ${store.level + 1}',
                        style: const TextStyle(fontSize: 13.5, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            RoundedProgress(value: store.levelProgress, height: 12),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(label: 'Melhor pontuação', value: '${store.bestClassicScore}'),
                ),
                Expanded(
                  child: _MiniStat(label: 'Recorde sobrevivência', value: '${store.bestSurvival}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(label: 'Precisão', value: '${(store.accuracy * 100).round()}%'),
                ),
                Expanded(
                  child: _MiniStat(label: 'Maior combo', value: 'x${store.bestCombo}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelRing extends StatelessWidget {
  const _LevelRing({required this.level, required this.progress});

  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 74,
    child: Stack(
      fit: StackFit.expand,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: progress),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => CircularProgressIndicator(
            value: v,
            strokeWidth: 7,
            strokeCap: StrokeCap.round,
            color: AppColors.brand500,
            backgroundColor: AppColors.brand100,
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'NÍVEL',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.inkMuted,
                ),
              ),
              Text('$level', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.1)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label, value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
      ),
    ],
  );
}

/// Grade responsiva de cartões (1 a 3 colunas) com alturas iguais por linha.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const gap = 16.0;
      final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 600 ? 2 : 1);
      return Column(
        children: [
          for (var i = 0; i < children.length; i += cols)
            Padding(
              padding: EdgeInsets.only(bottom: i + cols < children.length ? gap : 0),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < cols; j++) ...[
                      if (j > 0) const SizedBox(width: gap),
                      Expanded(child: i + j < children.length ? children[i + j] : const SizedBox()),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _EmojiTile extends StatelessWidget {
  const _EmojiTile({required this.emoji, required this.tone});

  static const size = 56.0;

  final String emoji;
  final Tone tone;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(size * 0.32)),
    child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.tags,
    required this.tone,
    required this.onTap,
  });

  final String emoji, title, description;
  final List<String> tags;
  final Tone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
    onTap: onTap,
    radius: AppRadius.xxl,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _EmojiTile(emoji: emoji, tone: tone),
            const Spacer(),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.ink),
          ],
        ),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text(description, style: mutedText.copyWith(fontSize: 14.5)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in tags)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(
                  t,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tone.foreground),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ChestCard extends StatelessWidget {
  const _ChestCard();

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final int won;
    try {
      won = await PlayerScope.read(context).openChest();
    } on BackendFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!context.mounted || won == 0) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Stack(
        children: [
          AlertDialog(
            title: const Text('🎁', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Headline('Baú [amber:aberto]!', size: 28, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  'Você ganhou $won 💎. Volte amanhã para abrir outro.',
                  textAlign: TextAlign.center,
                  style: mutedText,
                ),
              ],
            ),
            actions: [
              Center(
                child: PillButton(label: 'Pegar moedas', onPressed: () => Navigator.pop(context)),
              ),
            ],
          ),
          const Positioned.fill(child: Confetti(pieces: 90)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = PlayerScope.of(context).chestAvailable;
    return SoftCard(
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EmojiTile(emoji: '🎁', tone: Tone.amber),
          const SizedBox(height: 18),
          const Text('Baú diário', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            available ? 'Tem ${PlayerStore.chestCoins} 💎 esperando por você hoje.' : 'Já abriu hoje. Volte amanhã!',
            style: mutedText.copyWith(fontSize: 14.5),
          ),
          const Spacer(),
          const SizedBox(height: 16),
          PillButton(
            label: available ? 'Abrir baú' : 'Volte amanhã',
            kind: ButtonStyleKind.dark,
            onPressed: available ? () => unawaited(_open(context)) : null,
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    final store = PlayerScope.of(context);
    final streak = store.activeStreak;
    return SoftCard(
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EmojiTile(emoji: '🔥', tone: Tone.clay),
          const SizedBox(height: 18),
          Text(
            streak == 0 ? 'Comece uma ofensiva' : '$streak ${streak == 1 ? 'dia' : 'dias'} de ofensiva',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            store.playedToday
                ? 'Você já jogou hoje. Amanhã tem mais!'
                : 'Jogue uma partida hoje para ${streak == 0 ? 'começar' : 'não perder'} a sequência.',
            style: mutedText.copyWith(fontSize: 14.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i < (streak % 7 == 0 && streak > 0 ? 7 : streak % 7) ? AppColors.clayInk : AppColors.clay,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PowerUpsCard extends StatelessWidget {
  const _PowerUpsCard();

  @override
  Widget build(BuildContext context) => SoftCard(
    radius: AppRadius.xxl,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EmojiTile(emoji: '⚡', tone: Tone.stone),
        const SizedBox(height: 18),
        const Text('Ajudas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Use suas moedas durante a partida.', style: mutedText.copyWith(fontSize: 14.5)),
        const SizedBox(height: 14),
        for (final p in PowerUp.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(p.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(switch (p) {
                    PowerUp.fiftyFifty => '50/50: elimina 2 erradas',
                    PowerUp.extraTime => '+15 segundos no relógio',
                    PowerUp.skip => 'Pular sem perder vida',
                  }, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Text(
                  '💎${p.cost}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.brand700),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _Achievement {
  const _Achievement(this.emoji, this.name, this.description, this.unlocked);

  final String emoji, name, description;
  final bool unlocked;
}

class _Achievements extends StatelessWidget {
  const _Achievements();

  @override
  Widget build(BuildContext context) {
    final s = PlayerScope.of(context);
    final list = [
      _Achievement('🎯', 'Primeiro acerto', 'Acerte sua primeira questão', s.totalCorrect >= 1),
      _Achievement('🔥', 'Em chamas', 'Faça um combo de 5', s.bestCombo >= 5),
      _Achievement('⭐', 'Perfeccionista', 'Ganhe 3 estrelas numa partida de 10', s.bestClassicStars >= 3),
      _Achievement('♾️', 'Sobrevivente', 'Acerte 15 no modo Sobrevivência', s.bestSurvival >= 15),
      _Achievement('📅', 'Disciplina', 'Ofensiva de 7 dias', s.streakDays >= 7),
      _Achievement('🚀', 'Residente', 'Chegue ao nível 4', s.level >= 4),
      _Achievement('🧠', 'Centena', 'Responda 100 questões', s.totalAnswered >= 100),
      _Achievement('👑', 'Mestre da TC', 'Chegue ao nível 7', s.level >= 7),
    ];
    final unlocked = list.where((a) => a.unlocked).length;
    return SoftCard(
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$unlocked de ${list.length} desbloqueadas',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: context.isPhone ? 80 : 140,
                child: RoundedProgress(value: unlocked / list.length),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final a in list)
                Tooltip(
                  message: a.description,
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: a.unlocked ? AppColors.brand50 : AppColors.paper,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: a.unlocked ? AppColors.brand300 : AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Opacity(
                          opacity: a.unlocked ? 1 : 0.3,
                          child: Text(a.emoji, style: const TextStyle(fontSize: 28)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: a.unlocked ? AppColors.ink : AppColors.inkMuted,
                          ),
                        ),
                        Text(
                          a.description,
                          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showHowToPlay(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: const [
        Headline('Como [brand:funciona]', size: 30),
        SizedBox(height: 18),
        _Rule('❤️', 'Você tem 3 vidas. Errar ou deixar o tempo acabar custa uma.'),
        _Rule('🔥', 'Acertos seguidos viram combo: x1,5 com 3, x2 com 5 e x3 com 8.'),
        _Rule('⏱️', 'Quanto mais rápido você responde, mais pontos ganha.'),
        _Rule('💎', 'Cada acerto dá moedas para usar nas ajudas: 50/50, +15s e pular.'),
        _Rule('⭐', 'Nas partidas de 10 questões, 5 acertos = 1 estrela, 7 = 2 e 9 = 3.'),
        _Rule('✨', 'Ganhe XP para subir de nível e desbloquear conquistas.'),
        _Rule('🎁', 'Abra o baú todo dia e mantenha sua ofensiva.'),
      ],
    ),
  ),
);

class _Rule extends StatelessWidget {
  const _Rule(this.emoji, this.text);

  final String emoji, text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 15.5, height: 1.5, fontWeight: FontWeight.w500)),
        ),
      ],
    ),
  );
}
