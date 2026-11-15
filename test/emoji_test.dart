import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imagivet/widgets/emoji.dart';

/// Todo emoji escrito no código precisa ter o desenho do OpenMoji em assets/openmoji/.
void main() {
  test('cada emoji usado no jogo tem o arquivo do OpenMoji', () {
    final used = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      used.addAll(OpenMoji.pattern.allMatches(f.readAsStringSync()).map((m) => m[0]!));
    }
    expect(used, isNotEmpty);
    for (final e in used) {
      final code = OpenMoji.codeOf(e);
      expect(code, isNotNull, reason: 'sem desenho para $e');
      expect(File('assets/openmoji/$code.svg').existsSync(), isTrue, reason: 'falta assets/openmoji/$code.svg');
    }
    // Nenhum arquivo sobrando sem uso na lista.
    expect(OpenMoji.available.every((c) => File('assets/openmoji/$c.svg').existsSync()), isTrue);
  });
}
