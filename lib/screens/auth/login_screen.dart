import 'package:flutter/material.dart';

import '../../state/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../privacy_policy_screen.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false, _googleLoading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Carrega o logo do Google antes, para o botão não aparecer sem ele.
    precacheImage(const AssetImage(googleLogoAsset), context);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    dismissKeyboard();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthScope.read(context).signIn(email: _email.text, password: _password.text);
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
    final busy = _loading || _googleLoading;
    return AuthScaffold(
      title: 'Bom te ver [brand:de novo]',
      subtitle: 'Entre para salvar seu nível, suas moedas e disputar o ranking.',
      content: [
        GoogleButton(label: 'Entrar com o Google', onPressed: busy ? null : _google, loading: _googleLoading),
        const OrDivider(),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  icon: Icons.lock_outline,
                  password: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                  validator: (v) => (v ?? '').isEmpty ? 'Informe sua senha.' : null,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextLink(
            'Esqueci minha senha',
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim()))),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 8), MessageBanner(_error!)],
        const SizedBox(height: 16),
        PillButton(label: _loading ? 'Entrando...' : 'Entrar', expand: true, onPressed: busy ? null : _signIn),
      ],
      footer: [
        TextLink(
          'Criar conta',
          prefix: 'Ainda não tem conta?',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: busy ? null : () => AuthScope.read(context).continueAsGuest(),
            style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
            child: const Text('Continuar sem conta', style: TextStyle(fontSize: 13.5)),
          ),
        ),
        TextLink('Política de Privacidade', onPressed: () => PrivacyPolicyScreen.open(context)),
      ],
    );
  }
}
