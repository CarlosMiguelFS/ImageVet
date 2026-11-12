import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/privacy_config.dart';
import '../config/supabase_config.dart';

enum AuthStatus { signedOut, signedIn, guest, passwordRecovery }

enum SignUpResult { signedIn, confirmEmail }

class AppUser {
  const AppUser({required this.email, this.name});

  final String email;
  final String? name;
}

/// Erro de autenticação já traduzido para mostrar ao usuário.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Contrato da autenticação usado pelas telas.
abstract class AuthService extends ChangeNotifier {
  /// `false` quando o app roda sem Supabase (só modo sem conta).
  bool get isAvailable;
  AuthStatus get status;
  AppUser? get user;

  Future<void> init();
  Future<void> signIn({required String email, required String password});
  Future<SignUpResult> signUp({required String name, required String email, required String password});
  Future<void> signInWithGoogle();
  Future<bool> emailExists(String email);
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> signOut();
  Future<void> continueAsGuest();
  Future<void> leaveGuestMode();
}

/// Usado quando o Supabase não está configurado: o app funciona sem conta.
class LocalAuthService extends AuthService {
  @override
  bool get isAvailable => false;
  @override
  AuthStatus get status => AuthStatus.guest;
  @override
  AppUser? get user => null;

  @override
  Future<void> init() async {}

  Never _unavailable() => throw const AuthFailure('Login indisponível nesta versão do app.');

  @override
  Future<void> signIn({required String email, required String password}) async => _unavailable();
  @override
  Future<SignUpResult> signUp({required String name, required String email, required String password}) async =>
      _unavailable();
  @override
  Future<void> signInWithGoogle() async => _unavailable();
  @override
  Future<bool> emailExists(String email) async => _unavailable();
  @override
  Future<void> sendPasswordReset(String email) async => _unavailable();
  @override
  Future<void> updatePassword(String password) async => _unavailable();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> continueAsGuest() async {}
  @override
  Future<void> leaveGuestMode() async {}
}

class SupabaseAuthService extends AuthService {
  static const _guestKey = 'guest_mode';

  GoTrueClient get _auth => Supabase.instance.client.auth;
  AuthStatus _status = AuthStatus.signedOut;
  bool _guest = false;

  @override
  bool get isAvailable => true;
  @override
  AuthStatus get status => _status;

  /// Provedor Google ativo no Supabase (consultado em `/auth/v1/settings`).
  /// Só guarda o "sim": enquanto estiver desligado, consulta de novo a cada clique.
  bool _googleEnabled = false;

  Future<bool> _isGoogleEnabled() async {
    if (_googleEnabled) return true;
    try {
      final res = await http
          .get(Uri.parse('${SupabaseConfig.url}/auth/v1/settings'), headers: {'apikey': SupabaseConfig.publishableKey})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return true; // Na dúvida, deixa o Supabase responder.
      final external = (jsonDecode(res.body) as Map<String, dynamic>)['external'] as Map<String, dynamic>?;
      return _googleEnabled = external?['google'] == true;
    } catch (_) {
      return true;
    }
  }

  @override
  AppUser? get user {
    final u = _auth.currentUser;
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    return AppUser(email: u.email ?? '', name: (meta['full_name'] ?? meta['name']) as String?);
  }

  /// Endereço para onde os links de e-mail e o Google devem voltar.
  String? get _redirectTo => kIsWeb ? Uri.base.origin : null;

  @override
  Future<void> init() async {
    _guest = (await SharedPreferences.getInstance()).getBool(_guestKey) ?? false;
    _status = _auth.currentSession != null ? AuthStatus.signedIn : _signedOutStatus;
    _auth.onAuthStateChange.listen((data) {
      final next = switch (data.event) {
        AuthChangeEvent.passwordRecovery => AuthStatus.passwordRecovery,
        AuthChangeEvent.signedOut => _signedOutStatus,
        // Durante a redefinição, mantém a tela de nova senha até ela ser salva.
        _ when _status == AuthStatus.passwordRecovery => AuthStatus.passwordRecovery,
        _ => data.session != null ? AuthStatus.signedIn : _signedOutStatus,
      };
      if (next != _status) {
        _status = next;
        notifyListeners();
      }
    });
  }

  AuthStatus get _signedOutStatus => _guest ? AuthStatus.guest : AuthStatus.signedOut;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw AuthFailure(_translate(e));
    } on PostgrestException catch (e) {
      throw AuthFailure(
        e.code == '54000'
            ? 'Muitas tentativas seguidas. Aguarde um minuto e tente de novo.'
            : 'Não foi possível verificar agora. Tente de novo em instantes.',
      );
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('Não foi possível concluir. Verifique sua conexão e tente de novo.');
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) => _guard(() async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  });

  @override
  Future<SignUpResult> signUp({required String name, required String email, required String password}) =>
      _guard(() async {
        final res = await _auth.signUp(
          email: email.trim(),
          password: password,
          // A versão aceita da Política de Privacidade vai para o perfil (LGPD).
          data: {'full_name': name.trim(), 'termos_versao': PrivacyConfig.termsVersion},
          emailRedirectTo: _redirectTo,
        );
        // Com confirmação de e-mail ativa, o Supabase não acusa e-mail repetido:
        // devolve um usuário sem identidades.
        if (res.user?.identities?.isEmpty ?? false) {
          throw const AuthFailure('Já existe uma conta com esse e-mail. Tente entrar ou recuperar a senha.');
        }
        return res.session != null ? SignUpResult.signedIn : SignUpResult.confirmEmail;
      });

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    if (!await _isGoogleEnabled()) {
      throw const AuthFailure('O acesso com Google ainda está sendo configurado. Por enquanto, use e-mail e senha.');
    }
    await _auth.signInWithOAuth(OAuthProvider.google, redirectTo: _redirectTo);
  });

  @override
  Future<bool> emailExists(String email) => _guard(() async {
    final result = await Supabase.instance.client.rpc<bool>('email_cadastrado', params: {'p_email': email.trim()});
    return result;
  });

  @override
  Future<void> sendPasswordReset(String email) => _guard(() async {
    await _auth.resetPasswordForEmail(email.trim(), redirectTo: _redirectTo);
  });

  @override
  Future<void> updatePassword(String password) => _guard(() async {
    await _auth.updateUser(UserAttributes(password: password));
    _status = AuthStatus.signedIn;
    notifyListeners();
  });

  @override
  Future<void> signOut() => _guard(() async {
    await _setGuest(false);
    await _auth.signOut();
    _status = AuthStatus.signedOut;
    notifyListeners();
  });

  @override
  Future<void> continueAsGuest() async {
    await _setGuest(true);
    _status = AuthStatus.guest;
    notifyListeners();
  }

  @override
  Future<void> leaveGuestMode() async {
    await _setGuest(false);
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> _setGuest(bool value) async {
    _guest = value;
    await (await SharedPreferences.getInstance()).setBool(_guestKey, value);
  }

  static String _translate(AuthException e) => switch (e.code) {
    'invalid_credentials' => 'E-mail ou senha incorretos.',
    'email_not_confirmed' => 'Confirme seu e-mail antes de entrar. O link está na sua caixa de entrada.',
    'user_already_exists' || 'email_exists' => 'Já existe uma conta com esse e-mail.',
    'weak_password' => 'Senha fraca. Use pelo menos 8 caracteres, misturando letras e números.',
    'same_password' => 'A nova senha precisa ser diferente da anterior.',
    'over_email_send_rate_limit' ||
    'over_request_rate_limit' => 'Muitas tentativas seguidas. Aguarde alguns minutos e tente de novo.',
    'validation_failed' => 'Confira se o e-mail foi digitado corretamente.',
    _ => 'Não foi possível concluir. Verifique sua conexão e tente de novo.',
  };
}

/// Disponibiliza o [AuthService] para a árvore de widgets.
class AuthScope extends InheritedNotifier<AuthService> {
  const AuthScope({super.key, required AuthService auth, required super.child}) : super(notifier: auth);

  static AuthService of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;

  static AuthService read(BuildContext context) => context.getInheritedWidgetOfExactType<AuthScope>()!.notifier!;
}
