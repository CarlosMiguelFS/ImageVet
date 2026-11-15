import 'package:flutter/material.dart';

import '../config/privacy_config.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Política de Privacidade (LGPD — Lei nº 13.709/2018).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TopBar(
          leading: RoundIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Voltar',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          center: const Center(child: Text('Privacidade', style: TextStyle(fontSize: 16))),
          trailing: const SizedBox(width: 48),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: context.isPhone ? 28 : 44),
            children: [
              ResponsiveBody(
                maxWidth: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      eyebrow: 'LGPD',
                      title: 'Política de [brand:Privacidade]',
                      subtitle: 'Versão ${PrivacyConfig.termsVersion}',
                    ),
                    const SizedBox(height: 28),
                    SoftCard(
                      padding: EdgeInsets.all(context.isPhone ? 20 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Section(
                            'Quem cuida dos seus dados',
                            'O controlador dos dados é a ${PrivacyConfig.controller}. Dúvidas, pedidos sobre seus '
                                'dados e contato com o encarregado podem ser feitos ${PrivacyConfig.contactText}.',
                          ),
                          const _Section(
                            'Quais dados coletamos',
                            '• Conta: e-mail e senha (guardada de forma criptografada pelo Supabase), ou os dados '
                                'básicos da sua conta Google (nome e e-mail).\n'
                                '• Perfil: nome, turma (opcional) e foto (opcional).\n'
                                '• Estudo: suas respostas às questões (qual questão, se acertou, pontos e data), '
                                'pontuação, acertos e sequência.\n'
                                '• Registro do aceite desta política (data e versão).\n'
                                'Não coletamos CPF, telefone, endereço, localização nem dados sensíveis.',
                          ),
                          const _Section(
                            'Para que usamos',
                            '• Criar e proteger sua conta (execução do serviço que você pediu).\n'
                                '• Salvar seu progresso e mostrar sua evolução.\n'
                                '• Montar o ranking dos jogadores cadastrados, que faz parte da proposta do app (legítimo interesse).\n'
                                '• Evitar fraudes e abusos, como pontuação falsa (legítimo interesse).',
                          ),
                          const _Section(
                            'Quem vê seus dados',
                            'Seu e-mail nunca é mostrado a outros jogadores. Todos os jogadores cadastrados aparecem no '
                                'ranking, que mostra apenas nome, turma, foto e pontos; você pode sair dele em '
                                '"Meu perfil". Os dados ficam no Supabase (banco de dados e '
                                'autenticação) e o site é hospedado na Vercel; esses serviços podem armazenar dados '
                                'fora do Brasil, com as garantias previstas na LGPD. Não vendemos nem compartilhamos '
                                'seus dados para publicidade.',
                          ),
                          const _Section(
                            'Por quanto tempo guardamos',
                            'Enquanto sua conta existir. As respostas com mais de 1 ano são apagadas '
                                'automaticamente. Ao excluir a conta, apagamos conta, perfil, foto e respostas.',
                          ),
                          const _Section(
                            'Seus direitos',
                            'Você pode, a qualquer momento, pelo próprio app em "Meu perfil":\n'
                                '• ver todos os dados guardados sobre você ("Ver meus dados");\n'
                                '• corrigir nome e turma e trocar ou remover a foto;\n'
                                '• sair do ranking (direito de oposição);\n'
                                '• excluir sua conta e todos os seus dados.\n'
                                'Outros pedidos previstos no art. 18 da LGPD podem ser feitos pelo contato acima. '
                                'Você também pode reclamar à Autoridade Nacional de Proteção de Dados (ANPD).',
                          ),
                          const _Section(
                            'Segurança',
                            'Usamos conexão criptografada (HTTPS), regras que impedem um jogador de ver ou alterar '
                                'dados de outro, pontuação calculada no servidor e limites contra abuso. Em caso de '
                                'incidente que possa trazer risco a você, avisaremos e comunicaremos a ANPD.',
                          ),
                          const _Section(
                            'Armazenamento no navegador',
                            'Usamos o armazenamento do navegador apenas para manter você conectado e guardar o '
                                'progresso no modo sem conta. Não usamos cookies de publicidade nem de rastreamento.',
                            last: true,
                          ),
                        ],
                      ),
                    ),
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

class _Section extends StatelessWidget {
  const _Section(this.title, this.body, {this.last = false});

  final String title, body;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(fontSize: 14.5, height: 1.6, color: AppColors.ink)),
      ],
    ),
  );
}
