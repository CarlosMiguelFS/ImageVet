import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

const googleLogoAsset = 'assets/icons/google_g.png';

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Informe seu e-mail.';
  if (!_emailPattern.hasMatch(v)) return 'Esse e-mail não parece válido.';
  return null;
}

String? validateNewPassword(String? value) {
  final v = value ?? '';
  if (v.length < 8) return 'Use pelo menos 8 caracteres.';
  if (!v.contains(RegExp('[A-Za-z]')) || !v.contains(RegExp('[0-9]'))) {
    return 'Misture letras e números.';
  }
  return null;
}

/// Estrutura comum das telas de acesso: fundo com patinhas, marca e cartão central.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    this.footer = const [],
  });

  final String title, subtitle;
  final List<Widget> content;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.7, -1),
                  radius: 1.4,
                  colors: [AppColors.brand100, AppColors.paper],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: context.gutter, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (canPop)
                            RoundIconButton(
                              icon: Icons.arrow_back,
                              tooltip: 'Voltar',
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          const Spacer(),
                          const BrandMark(),
                          const Spacer(),
                          if (canPop) const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Headline(title, size: context.isPhone ? 30 : 36, textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      Text(subtitle, textAlign: TextAlign.center, style: mutedText),
                      const SizedBox(height: 26),
                      SoftCard(
                        padding: EdgeInsets.all(context.isPhone ? 20 : 28),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
                      ),
                      if (footer.isNotEmpty) ...[const SizedBox(height: 20), ...footer],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.password = false,
    this.validator,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool password;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: c, width: w),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.password && _hidden,
          validator: widget.validator,
          autofillHints: widget.autofillHints,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          autocorrect: false,
          enableSuggestions: !widget.password,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w500),
            prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20, color: AppColors.inkMuted),
            suffixIcon: widget.password
                ? IconButton(
                    tooltip: _hidden ? 'Mostrar senha' : 'Esconder senha',
                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    color: AppColors.inkMuted,
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: border(AppColors.line),
            focusedBorder: border(AppColors.brand400, 1.5),
            errorBorder: border(AppColors.coralInk),
            focusedErrorBorder: border(AppColors.coralInk, 1.5),
            errorStyle: const TextStyle(color: AppColors.coralInk, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

/// Botão do Google seguindo a identidade visual dele: logo à esquerda e texto
/// centralizado, com o mesmo canto e borda dos campos do formulário.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        disabledForegroundColor: AppColors.inkMuted,
        side: const BorderSide(color: AppColors.lineStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ).copyWith(overlayColor: WidgetStateProperty.all(AppColors.brand50)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: loading
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Image.asset(googleLogoAsset, width: 20, height: 20, gaplessPlayback: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ),
  );
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        Expanded(child: Divider(color: AppColors.line)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('ou', style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
        ),
        Expanded(child: Divider(color: AppColors.line)),
      ],
    ),
  );
}

enum BannerTone { error, success, info }

/// Aviso dentro do cartão (erro, sucesso ou informação).
class MessageBanner extends StatelessWidget {
  const MessageBanner(this.message, {super.key, this.tone = BannerTone.error});

  final String message;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (tone) {
      BannerTone.error => (AppColors.coral, AppColors.coralInk, Icons.error_outline),
      BannerTone.success => (AppColors.brand50, AppColors.brand600, Icons.mark_email_read_outlined),
      BannerTone.info => (AppColors.paper, AppColors.inkMuted, Icons.info_outline),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: fg, fontSize: 14, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

/// Link de texto discreto, como "Esqueci minha senha".
class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, required this.onPressed, this.prefix});

  final String label;
  final String? prefix;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (prefix != null) Text('$prefix ', style: const TextStyle(color: AppColors.inkMuted, fontSize: 14)),
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand600,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    ],
  );
}

/// Fecha o teclado antes de enviar o formulário.
void dismissKeyboard() => SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
