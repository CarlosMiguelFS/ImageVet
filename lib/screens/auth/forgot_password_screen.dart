import 'package:flutter/material.dart';

import '../../state/auth_service.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';
import 'signup_screen.dart';

enum _Stage { form, sent, notFound }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  var _stage = _Stage.form;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    dismissKeyboard();
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = AuthScope.read(context);
    try {
      if (await auth.emailExists(_email.text)) {
        await auth.sendPasswordReset(_email.text);
        if (mounted) setState(() => _stage = _Stage.sent);
      } else {
        if (mounted) setState(() => _stage = _Stage.notFound);
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _createAccount() =>
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => SignUpScreen(initialEmail: _email.text.trim())));

  @override
  Widget build(BuildContext context) {
    final email = _email.text.trim();
    return switch (_stage) {
      _Stage.sent => AuthScaffold(
        title: 'Link [brand:enviado]',
        subtitle: 'Agora é só abrir seu e-mail.',
        content: [
          MessageBanner(
            'Enviamos um link para $email. Toque nele para criar uma nova senha. '
            'O link vale por pouco tempo; se não encontrar a mensagem, olhe a caixa de spam.',
            tone: BannerTone.success,
          ),
          const SizedBox(height: 20),
          PillButton(label: 'Voltar para o login', expand: true, onPressed: () => Navigator.of(context).pop()),
        ],
      ),
      _Stage.notFound => AuthScaffold(
        title: 'Conta não [coral:encontrada]',
        subtitle: 'Não achamos ninguém cadastrado com esse e-mail.',
        content: [
          MessageBanner('Não existe conta com o e-mail $email. Confira se digitou certo ou crie uma conta nova.'),
          const SizedBox(height: 20),
          PillButton(label: 'Criar uma conta', expand: true, onPressed: _createAccount),
          const SizedBox(height: 12),
          PillButton(
            label: 'Tentar outro e-mail',
            kind: ButtonStyleKind.outline,
            expand: true,
            onPressed: () => setState(() => _stage = _Stage.form),
          ),
        ],
      ),
      _Stage.form => AuthScaffold(
        title: 'Esqueceu a [brand:senha]?',
        subtitle: 'Informe o e-mail da sua conta e enviaremos um link para criar uma nova.',
        content: [
          Form(
            key: _form,
            child: AppTextField(
              label: 'E-mail',
              controller: _email,
              hint: 'voce@email.com',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: validateEmail,
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 16), MessageBanner(_error!)],
          const SizedBox(height: 20),
          PillButton(
            label: _loading ? 'Verificando...' : 'Enviar link',
            expand: true,
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    };
  }
}
