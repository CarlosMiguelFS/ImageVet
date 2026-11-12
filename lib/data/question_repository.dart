import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/question.dart';

Future<List<Question>> loadQuestions([AssetBundle? bundle]) async {
  final raw = await (bundle ?? rootBundle).loadString('assets/questions.json', cache: false);
  return [for (final e in jsonDecode(raw) as List) Question.fromJson(e as Map<String, dynamic>)];
}
