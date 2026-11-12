/// Configuração do Supabase do ImagiVet (projeto separado do SuturaVet).
///
/// A chave *publishable* pode ficar no app: ela só permite o que as regras de
/// segurança (RLS) do banco autorizam. NUNCA coloque aqui a chave secreta
/// (`sb_secret_...`), que dá acesso total ao banco.
///
/// Os valores também podem vir do build:
/// `flutter build web --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...`
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lcfwmnafpswlgmkxwlnl.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_MfjS4uBHDZ7bpZdCYf5Wyw_Ae2Ltgw9',
  );

  /// Sem URL o app funciona sem login, com o progresso salvo só no aparelho.
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
