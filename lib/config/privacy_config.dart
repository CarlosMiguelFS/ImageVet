/// Dados da Política de Privacidade (LGPD).
abstract final class PrivacyConfig {
  /// Mude a versão sempre que a política mudar: quem aceitou uma versão
  /// anterior verá o pedido de aceite de novo.
  static const termsVersion = '2026-11-12';

  /// Controlador dos dados (quem decide sobre o tratamento).
  static const controller = 'Equipe do projeto ImagiVet (Projeto de Extensão Integrado em Medicina Veterinária)';

  /// E-mail para pedidos dos titulares e do encarregado (DPO).
  /// PREENCHER antes de publicar: ex.: privacidade@imagivet.com.br
  static const contactEmail = String.fromEnvironment('PRIVACY_EMAIL', defaultValue: '');

  static String get contactText =>
      contactEmail.isEmpty ? 'pelo e-mail de contato do projeto, informado pela equipe' : 'pelo e-mail $contactEmail';
}
