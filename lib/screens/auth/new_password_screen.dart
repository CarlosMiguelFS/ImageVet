import 'package:flutter/material.dart';

import '../../state/auth_service.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';

/// Aberta quando a pessoa chega pelo link de "esqueci minha senha".
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    dismissKeyboard();
    setState(() {
      _loading = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthScope.read(context).updatePassword(_password.text);
      messenger.showSnackBar(const SnackBar(content: Text('Senha alterada. Bom jogo!')));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Crie uma [brand:nova senha]',
    subtitle: 'Escolha uma senha que você não use em outros sites.',
    content: [
      Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Nova senha',
                controller: _password,
                hint: 'Mínimo de 8 caracteres',
                icon: Icons.lock_outline,
                password: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: validateNewPassword,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Confirme a nova senha',
                controller: _confirm,
                icon: Icons.lock_outline,
                password: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                validator: (v) => v != _password.text ? 'As senhas não são iguais.' : null,
              ),
            ],
          ),
        ),
      ),
      if (_error != null) ...[const SizedBox(height: 16), MessageBanner(_error!)],
      const SizedBox(height: 20),
      PillButton(
        label: _loading ? 'Salvando...' : 'Salvar nova senha',
        expand: true,
        onPressed: _loading ? null : _save,
      ),
    ],
  );
}
