import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Emojis desenhados pelo OpenMoji (https://openmoji.org/, licença CC BY-SA 4.0),
/// iguais em qualquer aparelho. Os arquivos ficam em `assets/openmoji/`, nomeados
/// pelo código Unicode (ex.: `2B50.svg` = ⭐), sem alterações.
abstract final class OpenMoji {
  /// Emojis que o jogo usa e que têm desenho em `assets/openmoji/`.
  static const available = {
    '1F331', '1F381', '1F389', '1F393', '1F396', '1F3AF', '1F3C6', '1F451', '1F48E', '1F494', '1F4C5', //
    '1F50E', '1F525', '1F680', '1F90D', '1F9E0', '1FA7A', '1FA7B', '23F1', '2699', '26A1', '267E', //
    '23ED', '23F0', '2702', '2728', '2764', '2B50',
  };

  /// Código do arquivo de um emoji (sem o seletor de variação FE0F), ou `null` se não houver desenho.
  static String? codeOf(String emoji) {
    final code = [
      for (final r in emoji.runes)
        if (r != 0xFE0F) r.toRadixString(16).toUpperCase(),
    ].join('-');
    return available.contains(code) ? code : null;
  }

  /// Um emoji (com o FE0F opcional), para separar os emojis dentro de um texto.
  static final pattern = RegExp(
    r'(?:[\u{1F300}-\u{1FAFF}]|[\u{2600}-\u{27BF}]|\u{2B50}|[\u{2300}-\u{23FF}])\u{FE0F}?',
    unicode: true,
  );
}

/// Mostra um emoji com o desenho do OpenMoji; sem desenho, usa o emoji do sistema.
class Emoji extends StatelessWidget {
  const Emoji(this.emoji, {super.key, this.size = 20});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = OpenMoji.codeOf(emoji);
    if (code == null) return Text(emoji, style: TextStyle(fontSize: size * 0.85, height: 1));
    return SvgPicture.asset('assets/openmoji/$code.svg', width: size, height: size, semanticsLabel: emoji);
  }
}

/// Texto em que cada emoji vira o desenho do OpenMoji, alinhado à linha.
class EmojiText extends StatelessWidget {
  const EmojiText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final size = (base.fontSize ?? 14) * 1.25;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in OpenMoji.pattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Emoji(m[0]!, size: size),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      textAlign: textAlign,
    );
  }
}
