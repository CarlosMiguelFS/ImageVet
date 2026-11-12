import 'package:flutter/material.dart';

import '../data/game_backend.dart';
import '../models/profile.dart';
import '../state/auth_service.dart';
import '../state/player_store.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'auth/auth_widgets.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  static const _top = 50;

  Future<List<RankingEntry>>? _future;
  String _period = 'semana';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<RankingEntry>> _load() async {
    final remote = PlayerScope.read(context).remote;
    if (remote == null) return const [];
    return remote.ranking(period: _period, limit: _top);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() => _future = next);
    await next.catchError((_) => <RankingEntry>[]);
  }

  @override
  Widget build(BuildContext context) {
    final store = PlayerScope.of(context);
    return Scaffold(
      body: Column(
        children: [
          TopBar(
            leading: RoundIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Voltar',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            center: const Center(child: Text('Ranking', style: TextStyle(fontSize: 16))),
            trailing: const SizedBox(width: 48),
          ),
          Expanded(
            child: !store.isOnline
                ? const _SignInToRank()
                : RefreshIndicator(
                    onRefresh: _reload,
                    color: AppColors.brand600,
                    child: FutureBuilder<List<RankingEntry>>(
                      future: _future,
                      builder: (context, snap) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(vertical: context.isPhone ? 28 : 44),
                        children: [
                          ResponsiveBody(
                            maxWidth: 640,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SectionHeader(
                                  eyebrow: 'Ranking',
                                  title: 'Quem está [brand:no topo]',
                                  subtitle: 'Todos os jogadores cadastrados, por pontuação. Puxe para atualizar.',
                                ),
                                const SizedBox(height: 22),
                                Center(
                                  child: _PeriodToggle(
                                    value: _period,
                                    onChanged: (p) {
                                      _period = p;
                                      _reload();
                                    },
                                  ),
                                ),
                                const SizedBox(height: 22),
                                ..._content(snap),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(AsyncSnapshot<List<RankingEntry>> snap) {
    if (snap.connectionState != ConnectionState.done) {
      return const [Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5)))];
    }
    if (snap.hasError) {
      final message = snap.error is BackendFailure
          ? (snap.error as BackendFailure).message
          : 'Não foi possível carregar o ranking.';
      return [
        MessageBanner(message),
        const SizedBox(height: 16),
        PillButton(label: 'Tentar de novo', kind: ButtonStyleKind.outline, onPressed: _reload),
      ];
    }
    final entries = snap.data ?? const [];
    if (entries.isEmpty) {
      return const [
        MessageBanner(
          'Ainda não há ninguém no ranking. Responda algumas questões e saia na frente!',
          tone: BannerTone.info,
        ),
      ];
    }
    final top = entries.where((e) => e.posicao <= _top).toList();
    final me = entries.where((e) => e.eu && e.posicao > _top).toList();
    final remote = PlayerScope.read(context).remote;
    return [
      for (final e in top) _RankingRow(entry: e, avatarUrl: remote?.avatarUrl(e.avatarPath)),
      if (me.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: Icon(Icons.more_vert, color: AppColors.inkMuted)),
        ),
        _RankingRow(entry: me.first, avatarUrl: remote?.avatarUrl(me.first.avatarPath)),
      ],
      if (!entries.any((e) => e.eu)) ...[
        const SizedBox(height: 12),
        const MessageBanner(
          'Você não aparece no ranking porque desligou essa opção. Para voltar, ative "Aparecer no ranking" no seu perfil.',
          tone: BannerTone.info,
        ),
      ],
    ];
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.entry, this.avatarUrl});

  final RankingEntry entry;
  final String? avatarUrl;

  static const _medals = {1: Color(0xFFD4A537), 2: Color(0xFFA7ADB4), 3: Color(0xFFB87A4B)};

  @override
  Widget build(BuildContext context) {
    final medal = _medals[entry.posicao];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: AppRadius.xl,
        color: entry.eu ? AppColors.brand50 : AppColors.surface,
        borderColor: entry.eu ? AppColors.brand400 : AppColors.line,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: medal != null
                  ? Icon(Icons.emoji_events, color: medal, size: 26)
                  : Text(
                      '${entry.posicao}º',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
                    ),
            ),
            const SizedBox(width: 10),
            UserAvatar(name: entry.nome, url: avatarUrl, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.eu ? '${entry.nome} (você)' : entry.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    [
                      'Nível ${PlayerStore.levelFor(entry.xp)}',
                      if (entry.turma?.isNotEmpty ?? false) entry.turma!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.pontos}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Text('PONTOS', style: TextStyle(fontSize: 9.5, letterSpacing: 1.4, color: AppColors.inkMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInToRank extends StatelessWidget {
  const _SignInToRank();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 44),
    children: [
      ResponsiveBody(
        maxWidth: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              eyebrow: 'Ranking',
              title: 'Entre para [brand:competir]',
              subtitle:
                  'O ranking usa a pontuação salva na sua conta. No modo sem conta, os pontos ficam só neste aparelho.',
            ),
            const SizedBox(height: 28),
            if (AuthScope.of(context).isAvailable)
              PillButton(
                label: 'Entrar ou criar conta',
                icon: Icons.login,
                expand: true,
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  AuthScope.read(context).leaveGuestMode();
                },
              ),
          ],
        ),
      ),
    ],
  );
}

/// Alterna entre o ranking da semana e o geral.
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (id, label) in const [('semana', 'Semana'), ('geral', 'Geral')])
          Material(
            color: id == value ? AppColors.ink : Colors.transparent,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: id == value ? null : () => onChanged(id),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.isPhone ? 14 : 18, vertical: 10),
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: id == value ? Colors.white : AppColors.inkMuted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
