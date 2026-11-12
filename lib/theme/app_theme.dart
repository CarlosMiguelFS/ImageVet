// ImagiVet — Feito por Carlos Miguel Fernandes dos Santos.

import 'package:flutter/material.dart';

/// Paleta azul (do céu ao marinho) no estilo do AbacatePay: fundo claro,
/// texto azul-marinho, botões em pílula e destaques coloridos atrás das palavras.
abstract final class AppColors {
  // Marca: céu claro, azul-céu, azul-royal, aço e marinho
  static const brand50 = Color(0xFFF2F7FD);
  static const brand100 = Color(0xFFE3EEFB);
  static const brand200 = Color(0xFFC4DDF6);
  static const brand300 = Color(0xFF8EC5F0);
  static const brand400 = Color(0xFF5AA9E6);
  static const brand500 = Color(0xFF2F6FD0);
  static const brand600 = Color(0xFF1F4FA8);
  static const brand700 = Color(0xFF18306E);

  // Texto e superfícies
  static const ink = Color(0xFF0F1A33);
  static const inkSoft = Color(0xFF2E3B57);
  static const inkMuted = Color(0xFF6B7891);
  static const paper = Color(0xFFF5F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE2E9F3);
  static const lineStrong = Color(0xFFCDD8E8);

  // Destaques ("pílulas" nos títulos) e estados do jogo
  static const clay = Color(0xFFE4E8FA);
  static const clayInk = Color(0xFF2B3A8F);
  static const mint = Color(0xFFDDF3E6);
  static const mintInk = Color(0xFF1E7A4C);
  static const amber = Color(0xFFFFF1C9);
  static const amberInk = Color(0xFF8A6400);
  static const coral = Color(0xFFFCE1DD);
  static const coralInk = Color(0xFFC2402D);
  static const stone = Color(0xFFE3EEF5);
  static const stoneInk = Color(0xFF3E6A8C);
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const xxl = 30.0;
  static const pill = 999.0;
}

abstract final class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x0A0F1A33), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x140F1A33), blurRadius: 24, spreadRadius: -12, offset: Offset(0, 10)),
  ];
  static const lifted = [
    BoxShadow(color: Color(0x0F0F1A33), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x2E0F1A33), blurRadius: 40, spreadRadius: -18, offset: Offset(0, 22)),
  ];
  static const glow = [BoxShadow(color: Color(0x661F4FA8), blurRadius: 28, spreadRadius: -12, offset: Offset(0, 12))];
}

abstract final class AppTheme {
  static const fontFamily = 'PlusJakartaSans';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand500, surface: AppColors.surface).copyWith(
      primary: AppColors.brand600,
      onPrimary: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.lineStrong,
      outlineVariant: AppColors.line,
      error: AppColors.coralInk,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.paper,
      splashFactory: InkRipple.splashFactory,
      dividerColor: AppColors.line,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.lineStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      ),
    );
  }
}
