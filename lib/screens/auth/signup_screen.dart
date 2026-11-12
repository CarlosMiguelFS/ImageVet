import 'package:flutter/material.dart';

import '../../state/auth_service.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';
import 'consent_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false, _googleLoading = false;
  bool _agreed = false, _showAgreeError = false;
  String? _error;

  /// E-mail para o qual a confirmação foi enviada.
  String? _sentTo;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _signUp() async {
    final valid = _form.currentState!.validate();
    setState(() => _showAgreeError = !_agreed);
    if (!valid || !_agreed) return;
    dismissKeyboard();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AuthScope.read(context)
          .signUp(name: _name.text, email: _email.text, password: _password.text);
      if (!mounted) return;
      if (result == SignUpResult.signedIn) {
        // A tela inicial aparece por baixo; fecha as telas de acesso empilhadas.
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        setState(() => _sentTo = _email.text.trim());
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await AuthScope.read(context).signInWithGoogle();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sentTo != null) {
      return AuthScaffold(
        title: 'Confira seu [brand:e-mail]',
        subtitle: 'Falta só um passo para ativar sua conta.',
        content: [
          MessageBanner(
            'Enviamos um link de confirmação para $_sentTo. Abra a mensagem e toque no link para ativar a conta. '
            'Se não encontrar, olhe a caixa de spam.',
            tone: BannerTone.success,
          ),
          const SizedBox(height: 20),
          PillButton(label: 'Voltar para o login', expand: true, onPressed: () => Navigator.of(context).pop()),
        ],
      );
    }

    final busy = _loading || _googleLoading;
    return AuthScaffold(
      title: 'Crie sua [brand:conta]',
      subtitle: 'Leva menos de um minuto e seu progresso fica salvo.',
      content: [
        GoogleButton(label: 'Cadastrar com o Google', onPressed: busy ? null : _google, loading: _googleLoading),
        const OrDivider(),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Nome',
                  controller: _name,
                  hint: 'Como quer ser chamado(a)',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => (v ?? '').trim().length < 2 ? 'Informe seu nome.' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'E-mail',
                  controller: _email,
                  hint: 'voce@email.com',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Senha',
                  controller: _password,
                  hint: 'Mínimo de 8 caracteres',
                  icon: Icons.lock_outline,
                  password: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validateNewPassword,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirme a senha',
                  controller: _confirm,
                  icon: Icons.lock_outline,
                  password: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signUp(),
                  validator: (v) => v != _password.text ? 'As senhas não são iguais.' : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ConsentCheckbox(
          value: _agreed,
          onChanged: (v) => setState(() {
            _agreed = v;
            if (v) _showAgreeError = false;
          }),
          errorText: _showAgreeError ? 'Para criar a conta, aceite a Política de Privacidade.' : null,
        ),
        if (_error != null) ...[const SizedBox(height: 16), MessageBanner(_error!)],
        const SizedBox(height: 20),
        PillButton(
          label: _loading ? 'Criando conta...' : 'Criar conta',
          expand: true,
          onPressed: busy ? null : _signUp,
        ),
      ],
      footer: [TextLink('Entrar', prefix: 'Já tem conta?', onPressed: () => Navigator.of(context).maybePop())],
    );
  }
}
