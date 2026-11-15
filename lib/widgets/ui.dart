import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'emoji.dart';

extension Responsive on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isPhone => screenWidth < 640;
  double get gutter => screenWidth < 640 ? 16 : (screenWidth < 1100 ? 28 : 40);
}

/// Centraliza o conteúdo com largura máxima e margens laterais responsivas.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 1120});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth + context.gutter * 2),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.gutter),
        child: child,
      ),
    ),
  );
}

/// Cores dos destaques em pílula.
enum Tone {
  brand(AppColors.brand100, AppColors.brand600),
  clay(AppColors.clay, AppColors.clayInk),
  mint(AppColors.mint, AppColors.mintInk),
  amber(AppColors.amber, AppColors.amberInk),
  stone(AppColors.stone, AppColors.stoneInk),
  coral(AppColors.coral, AppColors.coralInk);

  const Tone(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

/// Título grosso; trechos `[tom:texto]` ganham um destaque em pílula colorida.
/// Ex.: `Domine a [brand:tomografia] jogando`.
class Headline extends StatelessWidget {
  const Headline(this.text, {super.key, this.size, this.textAlign = TextAlign.start, this.color = AppColors.ink});

  final String text;
  final double? size;
  final TextAlign textAlign;
  final Color color;

  static final _marker = RegExp(r'\[(\w+):([^\]]+)\]');

  @override
  Widget build(BuildContext context) {
    final fontSize = size ?? (context.screenWidth * 0.06).clamp(30.0, 60.0);
    final style = TextStyle(
      fontSize: fontSize,
      // Títulos leves e com letras mais juntas (Jost 400).
      fontWeight: FontWeight.w400,
      height: 1.14,
      letterSpacing: -fontSize * 0.02,
      color: color,
    );
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _marker.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final tone = Tone.values.firstWhere((t) => t.name == m[1], orElse: () => Tone.brand);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: fontSize * 0.05),
            padding: EdgeInsets.symmetric(horizontal: fontSize * 0.22, vertical: fontSize * 0.02),
            decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(fontSize * 0.4)),
            child: Text(
              m[2]!,
              style: style.copyWith(color: tone.foreground, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      style: style,
    );
  }
}

const mutedText = TextStyle(fontSize: 16, height: 1.6, color: AppColors.inkMuted, fontWeight: FontWeight.w400);

/// Etiqueta pequena e espaçada acima dos títulos.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = AppColors.brand600, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, letterSpacing: 2.4, color: color),
    );
    if (icon == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Flexible(child: label),
      ],
    );
  }
}

/// Cartão branco de cantos amplos, borda suave e leve elevação ao passar o mouse.
class SoftCard extends StatefulWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(24),
    this.radius = AppRadius.xl,
    this.color = AppColors.surface,
    this.borderColor = AppColors.line,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color borderColor;

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final radius = BorderRadius.circular(widget.radius);
    return MouseRegion(
      onEnter: interactive ? (_) => setState(() => _hover = true) : null,
      onExit: interactive ? (_) => setState(() => _hover = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: radius,
          border: Border.all(color: _hover ? AppColors.brand300 : widget.borderColor),
          boxShadow: _hover ? AppShadows.lifted : AppShadows.soft,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

enum ButtonStyleKind { primary, dark, outline }

/// Botão em pílula. O principal é azul-céu com texto escuro, como no AbacatePay.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.kind = ButtonStyleKind.primary,
    this.expand = false,
    this.big = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonStyleKind kind;
  final bool expand;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      ButtonStyleKind.primary => (AppColors.brand300, AppColors.ink, AppColors.brand300),
      ButtonStyleKind.dark => (AppColors.ink, Colors.white, AppColors.ink),
      ButtonStyleKind.outline => (AppColors.surface, AppColors.ink, AppColors.lineStrong),
    };
    final disabled = onPressed == null;
    final button = Material(
      color: disabled ? AppColors.line : bg,
      shape: StadiumBorder(side: BorderSide(color: disabled ? AppColors.line : border)),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: big ? 30 : 22, vertical: big ? 18 : 14),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: big ? 17 : 15,
                    fontWeight: FontWeight.w500,
                    color: disabled ? AppColors.inkMuted : fg,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 10),
                Icon(icon, size: big ? 20 : 18, color: disabled ? AppColors.inkMuted : fg),
              ],
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Pílula pequena com emoji e valor (moedas, vidas, ofensiva...).
class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.emoji, required this.value, this.tone = Tone.brand, this.tooltip});

  final String emoji;
  final String value;
  final Tone tone;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Emoji(emoji, size: 19),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: tone.foreground,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip!, child: pill);
  }
}

/// Logotipo: círculo azul com o "corte" de tomografia e o nome.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Logo do ImagiVet (tomógrafo com cão e gato), sem fundo.
      Image.asset(
        'assets/icons/logo.png',
        width: size * 1.6,
        height: size * 1.6,
        fit: BoxFit.contain,
        semanticLabel: 'Logo do ImagiVet',
      ),
      const SizedBox(width: 6),
      Text.rich(
        const TextSpan(
          children: [
            TextSpan(text: 'Imagi'),
            TextSpan(
              text: 'Vet',
              style: TextStyle(color: AppColors.brand600),
            ),
          ],
        ),
        style: TextStyle(fontSize: size * 0.7, fontWeight: FontWeight.w600, letterSpacing: -0.6, color: AppColors.ink),
      ),
    ],
  );
}

/// Barra de navegação flutuante, arredondada e branca.
class FloatingNav extends StatelessWidget {
  const FloatingNav({super.key, required this.leading, this.trailing = const []});

  final Widget leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ResponsiveBody(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              // Em telas estreitas o logo encolhe para caber ao lado das pílulas.
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: leading),
                ),
              ),
              const SizedBox(width: 8),
              for (var i = 0; i < trailing.length; i++) ...[if (i > 0) const SizedBox(width: 8), trailing[i]],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Botão redondo só com ícone.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      side: const BorderSide(color: AppColors.line),
    ),
  );
}

/// Barra de progresso arredondada.
class RoundedProgress extends StatelessWidget {
  const RoundedProgress({super.key, required this.value, this.height = 10, this.color = AppColors.brand500});

  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.pill),
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          LinearProgressIndicator(value: v, minHeight: height, color: color, backgroundColor: AppColors.brand100),
    ),
  );
}

/// Título de seção centralizado: etiqueta, título com destaques e subtítulo.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.eyebrow, required this.title, this.subtitle});

  final String eyebrow, title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Eyebrow(eyebrow),
      const SizedBox(height: 12),
      Headline(title, size: context.isPhone ? 30 : 38, textAlign: TextAlign.center),
      if (subtitle != null) ...[
        const SizedBox(height: 10),
        Text(subtitle!, textAlign: TextAlign.center, style: mutedText),
      ],
    ],
  );
}

/// Barra superior das telas internas: voltar, título e ação opcional.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.leading, this.center, this.trailing});

  final Widget leading;
  final Widget? center, trailing;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ResponsiveBody(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.soft,
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
            child: Row(
              children: [
                leading,
                Expanded(child: center ?? const SizedBox()),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Foto do jogador, com as iniciais quando não houver foto.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.url, this.size = 44});

  final String name;
  final String? url;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        _initials,
        style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w600, color: AppColors.brand600),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.brand100,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: size > 60 ? 4 : 2),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? fallback
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
            ),
    );
  }
}

/// Folha inferior com etiqueta, título e conteúdo rolável.
Future<void> showInfoSheet(
  BuildContext context, {
  required String eyebrow,
  required String title,
  required List<Widget> children,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(context.gutter, 4, context.gutter, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Eyebrow(eyebrow),
              const SizedBox(height: 10),
              Headline(title, size: 28),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    ),
  ),
);
