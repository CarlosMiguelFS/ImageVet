import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// O gabarito do servidor (supabase/schema.sql) precisa bater com as questões do app.
void main() {
  test('gabarito do banco = respostas de assets/questions.json', () {
    final questions = jsonDecode(File('assets/questions.json').readAsStringSync()) as List;
    final sql = File('supabase/schema.sql').readAsStringSync();
    final rows = {
      for (final m in RegExp(r'^\s*\((\d+), (\d), (\d)\)', multiLine: true).allMatches(sql))
        int.parse(m[1]!): (int.parse(m[2]!), int.parse(m[3]!)),
    };
    expect(rows, hasLength(questions.length));
    for (final q in questions.cast<Map<String, dynamic>>()) {
      final (answer, total) = rows[q['id']]!;
      expect(answer, q['answer'], reason: 'questão ${q['id']}');
      expect(total, (q['options'] as List).length, reason: 'questão ${q['id']}');
    }
  });
}
