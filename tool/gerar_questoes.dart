// Gera assets/questions.json a partir de tool/novas_questoes.txt e mostra as
// linhas do gabarito para o supabase/schema.sql.
//
// Uso (na pasta ImagiVet): dart run tool/gerar_questoes.dart
//
// As questões 1 a 20 já existentes são mantidas; as do arquivo de texto
// entram a partir da 21, sempre no banco "valendo".
import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/questions.json');
  final existing = (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  final kept = [
    for (final q in existing)
      if ((q['id'] as int) <= 20) {...q, 'set': (q['id'] as int) <= 10 ? 'teste' : 'valendo'},
  ];

  final parsed = _parse(File('tool/novas_questoes.txt').readAsLinesSync());
  var id = 21;
  final all = [
    ...kept,
    for (final q in parsed) {'id': id++, 'set': 'valendo', ...q},
  ];

  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(all)}\n');
  stdout.writeln('${all.length} questões (${parsed.length} novas).');
  for (final q in all) {
    stdout.writeln('  (${q['id']}, ${q['answer']}, ${(q['options'] as List).length}),');
  }
}

List<Map<String, dynamic>> _parse(List<String> lines) {
  final out = <Map<String, dynamic>>[];
  var level = 1;
  Map<String, dynamic>? current;
  List<String>? statement;

  void close() {
    final q = current;
    if (q == null) return;
    q['question'] = statement!.join('\n').trim();
    final options = q['options'] as List;
    final explanations = q['explanations'] as List;
    if (options.length < 2 || options.length != explanations.length || q['answer'] == null) {
      throw StateError('Questão incompleta: ${q['title']}');
    }
    out.add(q);
    current = null;
  }

  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.startsWith('#')) continue;
    if (line.startsWith('N|')) {
      close();
      level = int.parse(line.substring(2));
    } else if (line.startsWith('Q|')) {
      close();
      current = {
        'nivel': level,
        'title': line.substring(2),
        'options': <String>[],
        'answer': null,
        'explanations': <String>[],
      };
      statement = [];
    } else if (current == null) {
      continue;
    } else if (line.startsWith('E|') && current!['answer'] != null) {
      // Depois do R|, "E|" é explicação (antes, seria a alternativa E).
      (current!['explanations'] as List).add(line.substring(2));
    } else if (RegExp(r'^[A-E]\|').hasMatch(line)) {
      (current!['options'] as List).add(line.substring(2));
    } else if (line.startsWith('R|')) {
      current!['answer'] = 'ABCDE'.indexOf(line.substring(2).trim());
    } else if ((current!['options'] as List).isEmpty) {
      statement!.add(line);
    }
  }
  close();
  return out;
}
