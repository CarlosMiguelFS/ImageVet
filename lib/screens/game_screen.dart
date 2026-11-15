import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/question.dart';
import '../state/game_controller.dart';
import '../state/player_store.dart';
import '../theme/app_theme.dart';
import '../widgets/emoji.dart';
import '../widgets/ui.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.mode, required this.questions, this.random, this.practice = false});

  final GameMode mode;
  final List<Question> questions;
  final Random? random;

  /// Partida de teste ("Jogar agora"): mostra pontos e combos, mas nada vai para o perfil, o ranking
  /// ou o servidor, e as ajudas são grátis.
  final bool practice;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _game = GameController(
    mode: widget.mode,
    questions: widget.questions,
    random: widget.random,
  )..addListener(_onGameChanged);
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _reported = false;
  AnswerOutcome? _lastOutcome;

  /// Muda a cada resposta, para reiniciar as animações de acerto/erro.
  int _feedbackKey = 0;

  static const _letters = [
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyC,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyE,
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.practice) PlayerScope.read(context).beginMatch(widget.mode.id);
  }

  @override
  void dispose() {
    _game
      ..removeListener(_onGameChanged)
      ..dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    final outcome = _game.outcome;
    if (outcome != null && !identical(outcome, _lastOutcome) && !widget.practice) {
      _lastOutcome = outcome;
      final item = _game.item;
      final selected = outcome.selected;
      PlayerScope.read(context).reportAnswer(
        questionId: item.question.id,
        alternative: selected == null ? null : item.originalIndex(selected),
        timeLeft: _game.timeLeft,
        totalTime: _game.totalTime,
      );
    }
    if (_game.finished && !_reported) {
      _reported = true;
      unawaited(_finish());
    }
  }

  Future<void> _finish() async {
    final local = _game.summary();
    final store = PlayerScope.read(context);
    final change = widget.practice
        ? ProgressChange(
            levelBefore: store.level,
            levelAfter: store.level,
            newRecord: false,
            streakDays: store.activeStreak,
            streakIncreased: false,
          )
        : await store.recordMatch(local);
    final summary = change.confirmed ?? local;
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => ResultScreen(
          mode: widget.mode,
          summary: summary,
          change: change,
          livesLeft: _game.lives,
          questions: widget.questions,
          practice: widget.practice,
        ),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _answer(int? choice) {
    final outcome = _game.answer(choice);
    if (outcome == null) return;
    setState(() => _feedbackKey++);
    unawaited(outcome.correct ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact());
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted && _scroll.hasClients) {
        unawaited(
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    });
  }

  void _next() {
    _game.next();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _usePowerUp(PowerUp p) async {
    if (!_game.canUse(p)) return;
    if (widget.practice) {
      _game.apply(p);
      unawaited(HapticFeedback.selectionClick());
      return;
    }
    final store = PlayerScope.read(context);
    final ok = await store.buyPowerUp(powerUp: p.name, cost: p.cost, questionId: _game.item.question.id);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: EmojiText('Faltam ${p.cost - store.coins} 💎 para usar ${p.label}. Acerte questões para ganhar!'),
        ),
      );
      return;
    }
    _game.apply(p);
    unawaited(HapticFeedback.selectionClick());
  }

  Future<bool> _confirmQuit() async {
    if (_game.finished) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da partida?', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text(
          widget.practice
              ? 'É só uma partida de teste: nada dela é salvo.'
              : 'Os pontos que você já fez nesta partida ficam salvos.',
          style: mutedText,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar jogando')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
        ],
      ),
    );
    return leave ?? false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final i = _letters.indexOf(key);
    if (!_game.isAnswered && i >= 0 && i < _game.item.length) {
      _answer(i);
      return KeyEventResult.handled;
    }
    if (_game.isAnswered && (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space)) {
      _next();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final navigator = Navigator.of(context);
      if (await _confirmQuit()) {
        _game.quit();
        navigator.pop();
      }
    },
    child: Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: _game,
        builder: (context, _) => Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _Hud(game: _game, onClose: () => Navigator.maybePop(context)),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.only(top: 8, bottom: 24),
                        child: ResponsiveBody(
                          maxWidth: 760,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Shake(
                                key: ValueKey('shake-$_feedbackKey'),
                                active: _game.outcome != null && !_game.outcome!.correct,
                                child: _QuestionCard(game: _game, practice: widget.practice),
                              ),
                              const SizedBox(height: 16),
                              for (var i = 0; i < _game.item.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _OptionTile(
                                    letter: String.fromCharCode(65 + i),
                                    text: _game.item.option(i),
                                    state: _stateOf(i),
                                    onTap: _game.isAnswered || _game.removed.contains(i) ? null : () => _answer(i),
                                  ),
                                ),
                              if (!_game.isAnswered) ...[
                                const SizedBox(height: 6),
                                _PowerUps(game: _game, onUse: _usePowerUp, practice: widget.practice),
                              ] else ...[
                                const SizedBox(height: 6),
                                _Explanation(game: _game),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_game.outcome?.correct ?? false)
                        Positioned(
                          top: 0,
                          right: 0,
                          left: 0,
                          child: _PointsBurst(key: ValueKey('burst-$_feedbackKey'), outcome: _game.outcome!),
                        ),
                    ],
                  ),
                ),
                if (_game.isAnswered) _ContinueBar(game: _game, onNext: _next),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  _OptionState _stateOf(int i) {
    if (_game.removed.contains(i)) return _OptionState.removed;
    final o = _game.outcome;
    if (o == null) return _OptionState.idle;
    if (i == _game.item.correctIndex) return _OptionState.correct;
    if (i == o.selected) return _OptionState.wrong;
    return _OptionState.dimmed;
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game, required this.onClose});

  final GameController game;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final store = PlayerScope.of(context);
    final classic = game.mode == GameMode.classic;
    final position = classic
        ? 'Fase ${min(game.index + 1, game.totalQuestions)} de ${game.totalQuestions}'
        : '${game.correct} ${game.correct == 1 ? 'acerto' : 'acertos'} · recorde ${store.bestSurvival}';
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: ResponsiveBody(
        maxWidth: 760,
        child: Column(
          children: [
            Row(
              children: [
                RoundIconButton(icon: Icons.close, tooltip: 'Sair', onPressed: onClose),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        position,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 6),
                      RoundedProgress(
                        value: classic
                            ? (game.index + (game.isAnswered ? 1 : 0)) / game.totalQuestions
                            : (game.correct % 5) / 5,
                        height: 9,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _Hearts(lives: game.lives),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StatPill(emoji: '💎', value: '${store.coins}', tooltip: 'Moedas'),
                const SizedBox(width: 8),
                StatPill(emoji: '⭐', value: '${game.score}', tone: Tone.amber, tooltip: 'Pontos da partida'),
                const SizedBox(width: 8),
                _ComboBadge(combo: game.combo),
                const Spacer(),
                _TimerRing(seconds: game.timeLeft, total: game.totalTime, paused: game.isAnswered),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Hearts extends StatelessWidget {
  const _Hearts({required this.lives});

  final int lives;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$lives vidas',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedScale(
            scale: i < lives ? 1 : 0.8,
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            child: AnimatedOpacity(
              opacity: i < lives ? 1 : 0.35,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Emoji(i < lives ? '❤️' : '🤍', size: 23),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ComboBadge extends StatelessWidget {
  const _ComboBadge({required this.combo});

  final int combo;

  @override
  Widget build(BuildContext context) {
    final mult = GameController.multiplierFor(combo);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, a) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
        child: child,
      ),
      child: combo < 2
          ? const SizedBox(key: ValueKey('none'))
          : StatPill(
              key: ValueKey(combo),
              emoji: '🔥',
              value: mult > 1 ? 'x${_fmt(mult)}' : '$combo',
              tone: combo >= 5 ? Tone.coral : Tone.clay,
              tooltip: '$combo acertos seguidos',
            ),
    );
  }

  static String _fmt(double m) => m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1);
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.seconds, required this.total, required this.paused});

  final int seconds, total;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final color = seconds <= 5
        ? AppColors.coralInk
        : seconds <= 10
        ? AppColors.amberInk
        : AppColors.brand600;
    return Semantics(
      label: '$seconds segundos',
      child: SizedBox.square(
        dimension: 46,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: total == 0 ? 0 : seconds / total,
              strokeWidth: 4.5,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: AppColors.brand100,
            ),
            Center(
              child: paused
                  ? const Icon(Icons.pause_rounded, size: 18, color: AppColors.inkMuted)
                  : Text(
                      '$seconds',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.game, this.practice = false});

  final GameController game;
  final bool practice;

  @override
  Widget build(BuildContext context) {
    final q = game.item.question;
    return SoftCard(
      radius: AppRadius.xxl,
      padding: EdgeInsets.all(context.isPhone ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (practice)
                const StatPill(emoji: '🎓', value: 'Teste · não conta pontos', tone: Tone.mint)
              else
                const StatPill(emoji: '🩻', value: 'Tomografia', tone: Tone.brand),
              if (game.mode == GameMode.survival && game.totalTime < game.item.seconds)
                const StatPill(emoji: '⚡', value: 'Mais rápido!', tone: Tone.amber),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            q.title,
            style: TextStyle(
              fontSize: context.isPhone ? 20 : 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.6,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            q.question,
            style: TextStyle(fontSize: context.isPhone ? 15.5 : 17, height: 1.6, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed, removed }

class _OptionTile extends StatefulWidget {
  const _OptionTile({required this.letter, required this.text, required this.state, this.onTap});

  final String letter, text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final (bg, border, badgeBg, badgeFg) = switch (widget.state) {
      _OptionState.idle => (AppColors.surface, AppColors.line, AppColors.brand100, AppColors.brand700),
      _OptionState.correct => (AppColors.mint, AppColors.mintInk, AppColors.mintInk, Colors.white),
      _OptionState.wrong => (AppColors.coral, AppColors.coralInk, AppColors.coralInk, Colors.white),
      _OptionState.dimmed => (AppColors.surface, AppColors.line, AppColors.paper, AppColors.inkMuted),
      _OptionState.removed => (AppColors.paper, AppColors.line, AppColors.paper, AppColors.inkMuted),
    };
    final faded = widget.state == _OptionState.removed || widget.state == _OptionState.dimmed;
    final radius = BorderRadius.circular(AppRadius.xl);
    return AnimatedScale(
      scale: _pressed ? 0.97 : (widget.state == _OptionState.correct ? 1.02 : 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: widget.state == _OptionState.removed ? 0.4 : 1,
        duration: const Duration(milliseconds: 250),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: border, width: widget.state == _OptionState.idle ? 1.2 : 2),
            boxShadow: faded ? null : AppShadows.soft,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              hoverColor: AppColors.brand50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
                      child: switch (widget.state) {
                        _OptionState.correct => const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                        _OptionState.wrong => const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        _ => Text(
                          widget.letter,
                          style: TextStyle(fontWeight: FontWeight.w600, color: badgeFg),
                        ),
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: faded ? AppColors.inkMuted : AppColors.ink,
                          decoration: widget.state == _OptionState.removed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerUps extends StatelessWidget {
  const _PowerUps({required this.game, required this.onUse, this.practice = false});

  final GameController game;
  final ValueChanged<PowerUp> onUse;
  final bool practice;

  @override
  Widget build(BuildContext context) {
    final coins = PlayerScope.of(context).coins;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final p in PowerUp.values)
          Opacity(
            opacity: game.canUse(p) && (practice || coins >= p.cost) ? 1 : 0.45,
            child: Material(
              color: AppColors.surface,
              shape: const StadiumBorder(side: BorderSide(color: AppColors.lineStrong)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: game.canUse(p) ? () => onUse(p) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Emoji(p.emoji, size: 19),
                      const SizedBox(width: 6),
                      Text(p.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brand100,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: EmojiText(
                          practice ? 'grátis' : '💎${p.cost}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final o = game.outcome!;
    final item = game.item;
    final correctLetter = String.fromCharCode(65 + item.correctIndex);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child),
      ),
      child: SoftCard(
        radius: AppRadius.xxl,
        color: AppColors.brand50,
        borderColor: AppColors.brand200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Por que a resposta é essa'),
            const SizedBox(height: 10),
            _ExplanationLine(
              tone: Tone.mint,
              label: 'Alternativa $correctLetter (correta)',
              text: item.explanation(item.correctIndex),
            ),
            if (o.selected != null && !o.correct) ...[
              const SizedBox(height: 14),
              _ExplanationLine(
                tone: Tone.coral,
                label: 'Você marcou a ${String.fromCharCode(65 + o.selected!)}',
                text: item.explanation(o.selected!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExplanationLine extends StatelessWidget {
  const _ExplanationLine({required this.tone, required this.label, required this.text});

  final Tone tone;
  final String label, text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tone.foreground),
        ),
      ),
      const SizedBox(height: 8),
      Text(text, style: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.ink)),
    ],
  );
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.game, required this.onNext});

  final GameController game;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final o = game.outcome!;
    final (emoji, title, tone) = o.correct
        ? (game.combo >= 3 ? '🔥' : '🎉', _cheer(game.combo), Tone.mint)
        : o.timedOut
        ? ('⏰', 'Tempo esgotado!', Tone.amber)
        : ('💔', game.lives > 0 ? 'Quase! Perdeu uma vida' : 'Sem vidas!', Tone.coral);
    final last = game.lives <= 0 || (game.mode == GameMode.classic && game.index >= game.totalQuestions - 1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.translate(offset: Offset(0, 80 * (1 - v)), child: child),
      child: Container(
        decoration: BoxDecoration(
          color: tone.background,
          border: Border(top: BorderSide(color: tone.foreground.withValues(alpha: 0.25))),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: ResponsiveBody(
          maxWidth: 760,
          child: Row(
            children: [
              Emoji(emoji, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: tone.foreground),
                    ),
                    if (o.correct)
                      EmojiText(
                        '+${o.points} pontos · +${o.coins} 💎',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: tone.foreground),
                      ),
                  ],
                ),
              ),
              PillButton(
                label: last ? 'Ver resultado' : 'Continuar',
                kind: ButtonStyleKind.dark,
                icon: Icons.arrow_forward_rounded,
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _cheer(int combo) => switch (combo) {
    >= 8 => 'IMPARÁVEL!',
    >= 5 => 'Em chamas!',
    >= 3 => 'Combo!',
    _ => 'Mandou bem!',
  };
}

/// "+150" que sobe e some depois de um acerto.
class _PointsBurst extends StatelessWidget {
  const _PointsBurst({super.key, required this.outcome});

  final AnswerOutcome outcome;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Opacity(
        opacity: v < 0.7 ? 1 : (1 - (v - 0.7) / 0.3),
        child: Transform.translate(
          offset: Offset(0, 40 - 60 * v),
          child: Transform.scale(
            scale: 0.6 + 0.5 * Curves.elasticOut.transform(v.clamp(0, 1)),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: AppShadows.glow,
                ),
                child: Text(
                  '+${outcome.points}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Treme o filho uma vez quando [active] é verdadeiro (resposta errada).
class _Shake extends StatelessWidget {
  const _Shake({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      builder: (context, v, child) =>
          Transform.translate(offset: Offset(sin(v * pi * 6) * 10 * (1 - v), 0), child: child),
      child: child,
    );
  }
}
