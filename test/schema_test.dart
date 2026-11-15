import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// O gabarito do servidor (supabase/schema.sql) precisa bater com as questões do app.
void main() {
  test('gabarito do banco = respostas e níveis de assets/questions.json', () {
    final questions = jsonDecode(File('assets/questions.json').readAsStringSync()) as List;
    final sql = File('supabase/schema.sql').readAsStringSync();
    final rows = {
      for (final m in RegExp(r'^\s*\((\d+), (\d), (\d), (\d)\)', multiLine: true).allMatches(sql))
        int.parse(m[1]!): (int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4]!)),
    };
    // O "Jogar agora" não passa pelo servidor: só as questões que valem pontos têm gabarito no banco.
    final scoring = questions.cast<Map<String, dynamic>>().where((q) => q['set'] != 'teste').toList();
    expect(rows, hasLength(scoring.length));
    expect(sql, contains('delete from public.gabarito where questao_id between 11 and 20;'));
    for (final q in scoring) {
      final (answer, total, level) = rows[q['id']]!;
      expect(answer, q['answer'], reason: 'questão ${q['id']}');
      expect(total, (q['options'] as List).length, reason: 'questão ${q['id']}');
      expect(level, q['nivel'], reason: 'nível da questão ${q['id']}');
    }
  });
}
