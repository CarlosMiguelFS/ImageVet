import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imagivet/config/privacy_config.dart';
import 'package:imagivet/models/profile.dart';
import 'package:imagivet/models/question.dart';
import 'package:imagivet/screens/auth/consent_screen.dart';
import 'package:imagivet/screens/auth/forgot_password_screen.dart';
import 'package:imagivet/screens/auth/login_screen.dart';
import 'package:imagivet/screens/auth/signup_screen.dart';
import 'package:imagivet/screens/game_screen.dart';
import 'package:imagivet/screens/home_screen.dart';
import 'package:imagivet/screens/privacy_policy_screen.dart';
import 'package:imagivet/screens/profile_screen.dart';
import 'package:imagivet/screens/ranking_screen.dart';
import 'package:imagivet/screens/result_screen.dart';
import 'package:imagivet/state/auth_service.dart';
import 'package:imagivet/state/game_controller.dart';
import 'package:imagivet/state/player_store.dart';
import 'package:imagivet/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Larguras de tela testadas: celular pequeno, celular comum e computador.
const _sizes = {'320px': Size(960, 2000), '390px': Size(1170, 2532), '1366px': Size(4098, 2700)};

List<Question> _questions() => [
  for (final e in jsonDecode(File('assets/questions.json').readAsStringSync()) as List)
    Question.fromJson(e as Map<String, dynamic>),
];

Future<void> _pump(WidgetTester tester, Size physical, Widget screen, {bool online = false}) async {
  tester.view.physicalSize = physical;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final store = PlayerStore();
  await store.load();
  if (online) {
    await store.attach(
      FakeBackend(
        profile: Profile(
          nome: 'Ana Beatriz Souza',
          turma: '5º período noturno',
          xp: 900,
          moedas: 240,
          pontos: 3100,
          termosVersao: PrivacyConfig.termsVersion,
          termosAceitosEm: DateTime(2026, 11, 12),
        ),
      ),
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (c, child) => AuthScope(
        auth: FakeAuth(online ? AuthStatus.signedIn : AuthStatus.guest),
        child: PlayerScope(store: store, child: child!),
      ),
      home: screen,
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  accountScreens();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    testWidgets('lobby cabe na tela ($name)', (tester) async {
      await _pump(tester, size, HomeScreen(questions: _questions()));
    });

    testWidgets('partida cabe na tela antes e depois de responder ($name)', (tester) async {
      await _pump(tester, size, GameScreen(mode: GameMode.classic, questions: _questions()));
      await tester.ensureVisible(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('A'));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('resultado cabe na tela, inclusive subindo de nível ($name)', (tester) async {
      await _pump(
        tester,
        size,
        ResultScreen(
          mode: GameMode.classic,
          summary: const MatchSummary(
            mode: 'classic',
            score: 2480,
            correct: 9,
            answered: 10,
            maxCombo: 9,
            xp: 900,
            coins: 95,
            stars: 3,
          ),
          change: const ProgressChange(
            levelBefore: 2,
            levelAfter: 3,
            newRecord: true,
            streakDays: 4,
            streakIncreased: true,
          ),
          livesLeft: 2,
          questions: _questions(),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
    });
  }
}

/// Telas de conta, perfil e ranking nas três larguras.
void accountScreens() {
  final screens = <String, (Widget, bool)>{
    'login': (const LoginScreen(), false),
    'cadastro': (const SignUpScreen(), false),
    'esqueci a senha': (const ForgotPasswordScreen(), false),
    'aceite da política': (const ConsentScreen(), true),
    'política de privacidade': (const PrivacyPolicyScreen(), false),
    'perfil': (const ProfileScreen(), true),
    'ranking': (const RankingScreen(), true),
    'ranking sem conta': (const RankingScreen(), false),
    'lobby com conta': (HomeScreen(questions: _questions()), true),
  };
  for (final MapEntry(key: size, value: physical) in _sizes.entries) {
    for (final MapEntry(key: name, value: (screen, online)) in screens.entries) {
      testWidgets('$name cabe na tela ($size)', (tester) async {
        await _pump(tester, physical, screen, online: online);
        await tester.pump(const Duration(milliseconds: 300));
      });
    }
  }
}
