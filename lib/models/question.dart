import 'dart:math';

/// Os dois bancos de questões do jogo.
enum QuestionSet {
  principais('principais', 'Perguntas principais'),
  casos('casos', 'Casos clínicos');

  const QuestionSet(this.id, this.label);
  final String id;
  final String label;

  static QuestionSet fromId(String? id) => values.firstWhere((s) => s.id == id, orElse: () => principais);
}

class Question {
  const Question({
    required this.id,
    this.set = QuestionSet.principais,
    required this.title,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanations,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
    id: j['id'] as int,
    set: QuestionSet.fromId(j['set'] as String?),
    title: j['title'] as String,
    question: j['question'] as String,
    options: List<String>.from(j['options'] as List),
    answer: j['answer'] as int,
    explanations: List<String>.from(j['explanations'] as List),
  );

  final int id;

  /// Banco a que a questão pertence (perguntas principais ou casos clínicos).
  final QuestionSet set;
  final String title;
  final String question;
  final List<String> options;
  final int answer;

  /// Explicação de cada alternativa, na mesma ordem de [options].
  final List<String> explanations;
}

/// Questão pronta para a partida, com as alternativas embaralhadas.
class QuizItem {
  QuizItem._(this.question, this._order);

  factory QuizItem.shuffled(Question q, Random rng) =>
      QuizItem._(q, List.generate(q.options.length, (i) => i)..shuffle(rng));

  final Question question;

  /// Posição original (no arquivo) de cada alternativa mostrada.
  final List<int> _order;

  int get length => _order.length;
  String option(int shown) => question.options[_order[shown]];
  String explanation(int shown) => question.explanations[_order[shown]];
  int originalIndex(int shown) => _order[shown];
  int get correctIndex => _order.indexOf(question.answer);

  /// Tempo base para responder: textos longos ganham mais tempo.
  int get seconds {
    final chars = question.question.length + question.options.fold<int>(0, (sum, o) => sum + o.length);
    return (chars / 14).round().clamp(25, 70);
  }
}
