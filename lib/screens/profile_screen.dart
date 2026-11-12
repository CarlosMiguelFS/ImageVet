import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/game_backend.dart';
import '../state/auth_service.dart';
import '../state/player_store.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'auth/auth_widgets.dart';
import 'privacy_policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _turma = TextEditingController();
  bool _noRanking = true;
  bool _loaded = false, _saving = false, _uploading = false;
  String? _error, _success;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = PlayerScope.of(context).profile;
    if (!_loaded && profile != null) {
      _loaded = true;
      _name.text = profile.nome;
      _turma.text = profile.turma ?? '';
      _noRanking = profile.noRanking;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _turma.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    dismissKeyboard();
    setState(() {
      _saving = true;
      _error = _success = null;
    });
    try {
      await PlayerScope.read(context).saveProfile(nome: _name.text, turma: _turma.text, noRanking: _noRanking);
      if (mounted) setState(() => _success = 'Perfil atualizado.');
    } on BackendFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    final store = PlayerScope.read(context);
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
    } catch (_) {
      setState(() => _error = 'Não foi possível abrir suas fotos.');
      return;
    }
    if (file == null) return;
    setState(() {
      _uploading = true;
      _error = _success = null;
    });
    try {
      final bytes = await file.readAsBytes();
      await store.changeAvatar(bytes, _mimeOf(file));
      if (mounted) setState(() => _success = 'Foto atualizada.');
    } on BackendFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  static String _mimeOf(XFile file) {
    final mime = file.mimeType;
    if (mime != null && mime.isNotEmpty) return mime;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final store = PlayerScope.of(context);
    final profile = store.profile;
    final phone = context.isPhone;

    return Scaffold(
      body: Column(
        children: [
          TopBar(
            leading: RoundIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Voltar',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            center: const Center(child: Text('Meu perfil', style: TextStyle(fontSize: 16))),
            trailing: const SizedBox(width: 48),
          ),
          Expanded(
            child: profile == null
                ? _LoadingProfile(onRetry: store.refresh)
                : ListView(
                    padding: EdgeInsets.symmetric(vertical: phone ? 28 : 44),
                    children: [
                      ResponsiveBody(
                        maxWidth: 560,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: _AvatarPicker(
                                name: profile.nome,
                                url: store.avatarUrl,
                                uploading: _uploading,
                                onTap: _uploading ? null : _pickPhoto,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Headline(
                              'Olá, [brand:${profile.primeiroNome}]',
                              size: phone ? 28 : 34,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (profile.turma?.isNotEmpty ?? false) ? profile.turma! : 'Toque na foto para trocar',
                              textAlign: TextAlign.center,
                              style: mutedText,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _ProfileStat(emoji: '🎖️', value: '${store.level}', label: store.title),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _ProfileStat(emoji: '⭐', value: '${store.totalScore}', label: 'Pontos'),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _ProfileStat(emoji: '💎', value: '${store.coins}', label: 'Moedas'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SoftCard(
                              padding: EdgeInsets.all(phone ? 20 : 28),
                              child: Form(
                                key: _form,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Eyebrow('Seus dados', icon: Icons.person_outline),
                                    const SizedBox(height: 18),
                                    AppTextField(
                                      label: 'Nome',
                                      controller: _name,
                                      icon: Icons.badge_outlined,
                                      keyboardType: TextInputType.name,
                                      validator: (v) {
                                        final t = (v ?? '').trim();
                                        if (t.length < 2) return 'Informe seu nome.';
                                        if (t.length > 60) return 'Use no máximo 60 caracteres.';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      label: 'Turma (opcional)',
                                      controller: _turma,
                                      hint: 'Ex.: 5º período noturno',
                                      icon: Icons.school_outlined,
                                      textInputAction: TextInputAction.done,
                                      validator: (v) =>
                                          (v ?? '').trim().length > 40 ? 'Use no máximo 40 caracteres.' : null,
                                    ),
                                    const SizedBox(height: 12),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      value: _noRanking,
                                      activeTrackColor: AppColors.brand500,
                                      onChanged: (v) => setState(() => _noRanking = v),
                                      title: const Text('Aparecer no ranking', style: TextStyle(fontSize: 15)),
                                      subtitle: const Text(
                                        'Todos os jogadores cadastrados aparecem com nome, turma, foto e pontos. '
                                        'Seu e-mail nunca aparece. Desligue se preferir não aparecer.',
                                        style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                                      ),
                                    ),
                                    if (_error != null) ...[const SizedBox(height: 12), MessageBanner(_error!)],
                                    if (_success != null) ...[
                                      const SizedBox(height: 12),
                                      MessageBanner(_success!, tone: BannerTone.success),
                                    ],
                                    const SizedBox(height: 20),
                                    PillButton(
                                      label: _saving ? 'Salvando...' : 'Salvar alterações',
                                      expand: true,
                                      onPressed: _saving ? null : _save,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            PillButton(
                              label: 'Sair da conta',
                              icon: Icons.logout,
                              kind: ButtonStyleKind.outline,
                              expand: true,
                              onPressed: () {
                                Navigator.of(context).popUntil((r) => r.isFirst);
                                AuthScope.read(context).signOut();
                              },
                            ),
                            const SizedBox(height: 28),
                            const _PrivacySection(),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Direitos do titular (LGPD): acesso aos dados, política e eliminação.
class _PrivacySection extends StatelessWidget {
  const _PrivacySection();

  Future<void> _showMyData(BuildContext context) async {
    final store = PlayerScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await store.myData();
      if (!context.mounted) return;
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      await showInfoSheet(
        context,
        eyebrow: 'LGPD',
        title: 'Seus [brand:dados]',
        children: [
          const Text('Tudo o que está guardado sobre você no ImagiVet:', style: mutedText),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.line),
            ),
            child: SingleChildScrollView(
              child: SelectableText(pretty, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.5)),
            ),
          ),
          const SizedBox(height: 14),
          PillButton(
            label: 'Copiar dados',
            icon: Icons.copy,
            kind: ButtonStyleKind.outline,
            expand: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: pretty));
              messenger.showSnackBar(const SnackBar(content: Text('Dados copiados.')));
            },
          ),
        ],
      );
    } on BackendFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => const _DeleteAccountDialog());
    if (confirmed != true || !context.mounted) return;
    final store = PlayerScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await store.deleteAccount();
      navigator.popUntil((r) => r.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('Sua conta e seus dados foram excluídos.')));
    } on BackendFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) => SoftCard(
    padding: EdgeInsets.all(context.isPhone ? 20 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('Privacidade e dados', icon: Icons.shield_outlined),
        const SizedBox(height: 10),
        const Text(
          'Pela LGPD, você pode ver tudo o que guardamos sobre você e excluir sua conta quando quiser.',
          style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 16),
        PillButton(
          label: 'Ver meus dados',
          icon: Icons.visibility_outlined,
          kind: ButtonStyleKind.outline,
          expand: true,
          onPressed: () => _showMyData(context),
        ),
        const SizedBox(height: 10),
        PillButton(
          label: 'Política de Privacidade',
          icon: Icons.policy_outlined,
          kind: ButtonStyleKind.outline,
          expand: true,
          onPressed: () => PrivacyPolicyScreen.open(context),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => _deleteAccount(context),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Excluir minha conta e meus dados'),
          style: TextButton.styleFrom(foregroundColor: AppColors.coralInk),
        ),
      ],
    ),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Excluir conta?', style: TextStyle(fontWeight: FontWeight.w800)),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Isso apaga sua conta, perfil, foto, pontuação e respostas. Não dá para desfazer.',
          style: mutedText,
        ),
        const SizedBox(height: 14),
        const Text('Digite EXCLUIR para confirmar:', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _confirm,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
      TextButton(
        onPressed: _confirm.text.trim().toUpperCase() == 'EXCLUIR' ? () => Navigator.pop(context, true) : null,
        style: TextButton.styleFrom(foregroundColor: AppColors.coralInk),
        child: const Text('Excluir'),
      ),
    ],
  );
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.name, required this.url, required this.uploading, this.onTap});

  final String name;
  final String? url;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Trocar foto de perfil',
    child: GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(name: name, url: url, size: 112),
            if (uploading)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x99FFFFFF), shape: BoxShape.circle),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 4,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.brand600,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                ),
                child: const Icon(Icons.photo_camera_outlined, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LoadingProfile extends StatelessWidget {
  const _LoadingProfile({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
        const SizedBox(height: 16),
        const Text('Carregando seu perfil...', style: mutedText),
        TextButton(onPressed: () => onRetry().catchError((_) {}), child: const Text('Tentar de novo')),
      ],
    ),
  );
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.emoji, required this.value, required this.label});

  final String emoji, value, label;

  @override
  Widget build(BuildContext context) => SoftCard(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
