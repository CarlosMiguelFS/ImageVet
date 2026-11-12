import 'package:flutter/material.dart';

import '../../config/privacy_config.dart';
import '../../data/game_backend.dart';
import '../../state/auth_service.dart';
import '../../state/player_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../privacy_policy_screen.dart';
import 'auth_widgets.dart';

/// Pede o aceite da Política de Privacidade antes de usar a conta (LGPD).
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false, _loading = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PlayerScope.read(context).acceptTerms(PrivacyConfig.termsVersion);
    } on BackendFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Seus dados, [mint:suas regras]',
    subtitle: 'Antes de continuar, leia como cuidamos das suas informações.',
    content: [
      const Text(
        'Guardamos seu nome, e-mail, turma (opcional), foto (opcional) e suas respostas para salvar seu '
        'progresso. Todos os jogadores cadastrados aparecem no ranking com nome, turma, foto e pontos; '
        'seu e-mail nunca aparece. Em "Meu perfil" você pode sair do ranking e ver ou apagar seus '
        'dados a qualquer momento.',
        style: TextStyle(fontSize: 14.5, height: 1.6),
      ),
      const SizedBox(height: 14),
      ConsentCheckbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v)),
      if (_error != null) ...[const SizedBox(height: 12), MessageBanner(_error!)],
      const SizedBox(height: 18),
      PillButton(
        label: _loading ? 'Salvando...' : 'Aceitar e continuar',
        expand: true,
        onPressed: _agreed && !_loading ? _accept : null,
      ),
    ],
    footer: [
      Center(
        child: TextButton(
          onPressed: () => AuthScope.read(context).signOut(),
          style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
          child: const Text('Não aceito, sair', style: TextStyle(fontSize: 13.5)),
        ),
      ),
    ],
  );
}

/// "Li e aceito a Política de Privacidade", com link para o texto completo.
class ConsentCheckbox extends StatelessWidget {
  const ConsentCheckbox({super.key, required this.value, required this.onChanged, this.errorText});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(value: value, activeColor: AppColors.brand600, onChanged: (v) => onChanged(v ?? false)),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => onChanged(!value),
                  child: const Text('Li e aceito a ', style: TextStyle(fontSize: 14)),
                ),
                TextLink('Política de Privacidade', onPressed: () => PrivacyPolicyScreen.open(context)),
              ],
            ),
          ),
        ],
      ),
      if (errorText != null)
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(errorText!, style: const TextStyle(color: AppColors.coralInk, fontSize: 12.5)),
        ),
    ],
  );
}
