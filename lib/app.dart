// ImagiVet — Feito por Carlos Miguel Fernandes dos Santos.

import 'package:flutter/material.dart';

import 'config/privacy_config.dart';
import 'data/game_backend.dart';
import 'data/question_repository.dart';
import 'models/question.dart';
import 'screens/auth/consent_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/new_password_screen.dart';
import 'screens/home_screen.dart';
import 'state/auth_service.dart';
import 'state/player_store.dart';
import 'theme/app_theme.dart';
import 'widgets/ui.dart';

class ImagiVetApp extends StatefulWidget {
  const ImagiVetApp({super.key, required this.auth, this.backend, this.store});

  final AuthService auth;

  /// Perfil, partidas e ranking na nuvem; usado quando há alguém logado.
  final GameBackend? backend;

  /// Permite injetar o progresso nos testes.
  final PlayerStore? store;

  @override
  State<ImagiVetApp> createState() => _ImagiVetAppState();
}

class _ImagiVetAppState extends State<ImagiVetApp> {
  late final PlayerStore _store = widget.store ?? PlayerStore();
  late final Future<List<Question>> _boot = _init();
  bool? _online;

  Future<List<Question>> _init() async {
    await _store.load();
    widget.auth.addListener(_syncAccount);
    await _syncAccount();
    return loadQuestions();
  }

  /// Usa o progresso da conta quando alguém entra e o do aparelho quando sai.
  Future<void> _syncAccount() async {
    final online = widget.auth.status == AuthStatus.signedIn && widget.backend != null;
    if (online == _online) return;
    _online = online;
    await _store.attach(online ? widget.backend : null);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_syncAccount);
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ImagiVet',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    builder: (context, child) => AuthScope(
      auth: widget.auth,
      child: PlayerScope(store: _store, child: child!),
    ),
    home: FutureBuilder<List<Question>>(
      future: _boot,
      builder: (context, snapshot) {
        if (snapshot.hasData) return _AuthGate(questions: snapshot.data!);
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 40),
                const SizedBox(height: 24),
                if (snapshot.hasError)
                  const Text('Não foi possível carregar o jogo.', style: mutedText)
                else
                  const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3)),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Escolhe a tela de entrada conforme a situação da conta.
class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.questions});

  final List<Question> questions;

  @override
  Widget build(BuildContext context) {
    final status = AuthScope.of(context).status;
    final needsConsent = PlayerScope.of(context).needsConsent(PrivacyConfig.termsVersion);
    return switch (status) {
      AuthStatus.signedOut => const LoginScreen(key: ValueKey('login')),
      AuthStatus.passwordRecovery => const NewPasswordScreen(key: ValueKey('new-password')),
      AuthStatus.signedIn when needsConsent => const ConsentScreen(key: ValueKey('consent')),
      AuthStatus.signedIn || AuthStatus.guest => HomeScreen(key: const ValueKey('home'), questions: questions),
    };
  }
}
