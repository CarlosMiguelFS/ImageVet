import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imagivet/app.dart';
import 'package:imagivet/config/privacy_config.dart';
import 'package:imagivet/models/profile.dart';
import 'package:imagivet/state/auth_service.dart';
import 'package:imagivet/state/player_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

final _accepted = Profile(
  nome: 'Ana Souza',
  termosVersao: PrivacyConfig.termsVersion,
  termosAceitosEm: DateTime(2026, 11, 12),
);

Future<void> _openApp(
  WidgetTester tester, {
  AuthService? auth,
  FakeBackend? backend,
  String waitFor = 'Jogar agora',
}) async {
  // Tela de celular (390 x 844).
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ImagiVetApp(auth: auth ?? LocalAuthService(), backend: backend));
  for (var i = 0; i < 40 && find.text(waitFor).evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await _settle(tester);
}

Future<void> _answerFirst(WidgetTester tester) async {
  await tester.tap(find.text('Jogar agora'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  expect(find.text('Fase 1 de 10'), findsOneWidget);
  await tester.ensureVisible(find.text('A'));
  await tester.pump();
  await tester.tap(find.text('A'));
  await tester.pump(const Duration(milliseconds: 1500));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sem Supabase: abre direto no jogo, responde e mostra a explicação', (tester) async {
    await _openApp(tester);
    expect(find.text('Entrar'), findsNothing);
    await _answerFirst(tester);
    expect(find.text('POR QUE A RESPOSTA É ESSA'), findsOneWidget);
    // Descarta a tela para cancelar o cronômetro.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('deslogado: mostra o login e permite jogar sem conta', (tester) async {
    final auth = FakeAuth();
    await _openApp(tester, auth: auth, backend: FakeBackend(), waitFor: 'Entrar com o Google');
    expect(find.text('Entrar com o Google'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);

    await tester.ensureVisible(find.text('Continuar sem conta'));
    await tester.tap(find.text('Continuar sem conta'));
    await _settle(tester);
    expect(find.text('Jogar agora'), findsOneWidget);
    expect(find.byTooltip('Entrar'), findsOneWidget, reason: 'botão para entrar na conta pelo lobby');
  });

  testWidgets('login com senha errada mostra o erro; com a certa pede o aceite da política', (tester) async {
    final auth = FakeAuth();
    final backend = FakeBackend();
    await _openApp(tester, auth: auth, backend: backend, waitFor: 'Entrar com o Google');

    await tester.enterText(find.byType(TextFormField).at(0), 'ana@exemplo.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'errada1');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await _settle(tester);
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'senha123');
    await tester.tap(find.text('Entrar'));
    await _settle(tester);
    // Perfil sem aceite: a política aparece antes do jogo (LGPD).
    expect(find.text('Aceitar e continuar'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Aceitar e continuar'));
    await tester.tap(find.text('Aceitar e continuar'));
    await _settle(tester);
    expect(find.text('Jogar agora'), findsOneWidget);
  });

  testWidgets('com conta: um nível abre a partida e cada resposta vai para o servidor', (tester) async {
    final backend = FakeBackend(profile: _accepted);
    await _openApp(tester, auth: FakeAuth(AuthStatus.signedIn), backend: backend);
    expect(find.text('Entrar'), findsNothing);
    expect(find.byTooltip('Meu perfil'), findsOneWidget);

    // Os cartões dos níveis ficam mais abaixo na tela inicial.
    await tester.scrollUntilVisible(find.text('Nível 1 · Fundamentos'), 300, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.text('Nível 1 · Fundamentos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Fase 1 de 10'), findsOneWidget);
    await tester.ensureVisible(find.text('A'));
    await tester.pump();
    await tester.tap(find.text('A'));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));

    expect(backend.modes, ['classic']);
    expect(backend.answers, hasLength(1));
    final (questionId, alternative) = backend.answers.single;
    expect(questionId, inInclusiveRange(21, 30), reason: 'nível 1 = questões 21 a 30');
    expect(alternative, inInclusiveRange(0, 3), reason: 'envia o índice original da alternativa');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('com conta: "Jogar agora" é um teste que mostra os pontos, mas não envia nada ao servidor', (
    tester,
  ) async {
    final backend = FakeBackend(profile: _accepted);
    await _openApp(tester, auth: FakeAuth(AuthStatus.signedIn), backend: backend);

    await tester.tap(find.text('Jogar agora'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Fase 1 de 10'), findsOneWidget);
    expect(find.text('Teste · não conta pontos'), findsOneWidget);
    expect(find.text('grátis'), findsNWidgets(3), reason: 'ajudas grátis no teste');

    await tester.ensureVisible(find.text('A'));
    await tester.pump();
    await tester.tap(find.text('A'));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(find.text('POR QUE A RESPOSTA É ESSA'), findsOneWidget);
    expect(backend.modes, isEmpty, reason: 'não abre partida no servidor');
    expect(backend.answers, isEmpty, reason: 'não envia respostas');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('com conta: o resultado mostrado é o confirmado pelo servidor', (tester) async {
    final backend = FakeBackend(profile: _accepted);
    final store = PlayerStore();
    await store.attach(backend);
    store.beginMatch('classic');
    final change = await store.recordMatch(
      const MatchSummary(
        mode: 'classic',
        score: 5000,
        correct: 10,
        answered: 10,
        maxCombo: 10,
        xp: 0,
        coins: 0,
        stars: 3,
      ),
    );
    expect(backend.finished, 1);
    expect(change.confirmed?.score, 999, reason: 'o servidor prevalece sobre o que o aparelho calculou');
    expect(change.confirmed?.stars, 2);
    expect(change.newRecord, isTrue);
    expect(store.totalScore, 999);
    expect(store.xp, 500);
  });

  testWidgets('com conta: ajuda desconta moedas no servidor', (tester) async {
    final backend = FakeBackend(profile: _accepted);
    final store = PlayerStore();
    await store.attach(backend);
    store.beginMatch('classic');
    expect(await store.buyPowerUp(powerUp: 'fiftyFifty', cost: 30, questionId: 1), isTrue);
    expect(store.coins, 70, reason: 'desconta na hora');
    expect(await store.buyPowerUp(powerUp: 'skip', cost: 400, questionId: 1), isFalse);
    await store.recordMatch(
      const MatchSummary(mode: 'classic', score: 0, correct: 0, answered: 0, maxCombo: 0, xp: 0, coins: 0, stars: 0),
    );
    expect(backend.powerUps, ['fiftyFifty']);
  });
}

/// Avança as animações sem depender de todas terminarem (o cursor do campo de
/// texto pisca para sempre).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
