import 'package:material_ui/material_ui.dart';

// Mâm — Chuẩn Fintech Việt Nam (Canon) Design Tokens
// First-class Light & Dark appearance with semantic roles and WCAG AA contrast.

const TextStyle kTabularStyle = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Print-safe palette for exported PNG Receipt Cards & VietQR cards.
/// Always renders on crisp white paper so bank apps scan reliably from Zalo/Messenger.
abstract final class MamReceiptColors {
  static const Color paper = Color(0xFFFFFFFF);
  static const Color subtle = Color(0xFFF4F6FA);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF526075);
  static const Color border = Color(0xFFE2E8F0);
  static const Color primary = Color(0xFF0066FF);
  static const Color success = Color(0xFF059669);
}

@immutable
class MamPalette extends ThemeExtension<MamPalette> {
  const MamPalette({
    required this.ground,
    required this.backdrop,
    required this.surface,
    required this.surfaceSubtle,
    required this.ink,
    required this.muted,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.heroBackground,
    required this.heroSettled,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.participantPalette,
  });

  final Color ground;
  final Color backdrop;
  final Color surface;
  final Color surfaceSubtle;
  final Color ink;
  final Color muted;
  final Color border;
  final Color primary;
  final Color primarySoft;
  final Color onPrimary;
  final Color heroBackground;
  final Color heroSettled;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final List<Color> participantPalette;

  Color participantColor(int index) =>
      participantPalette[index % participantPalette.length];

  static const MamPalette light = MamPalette(
    ground: Color(0xFFF4F6FA),
    backdrop: Color(0xFFE6ECF5),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFEDF1F7),
    ink: Color(0xFF0F172A),
    muted: Color(0xFF526075),
    border: Color(0xFFE2E8F0),
    primary: Color(0xFF0066FF),
    primarySoft: Color(0xFFEBF3FF),
    onPrimary: Color(0xFFFFFFFF),
    heroBackground: Color(0xFF005CE6),
    heroSettled: Color(0xFF047857),
    success: Color(0xFF059669),
    successSoft: Color(0xFFECFDF5),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFEF3C7),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0xFFFEF2F2),
    participantPalette: [
      Color(0xFF0066FF), // Banking Blue
      Color(0xFF059669), // Emerald
      Color(0xFF7C3AED), // Violet
      Color(0xFFD97706), // Amber
      Color(0xFF0891B2), // Cyan
      Color(0xFFDB2777), // Rose
      Color(0xFF4F46E5), // Indigo
      Color(0xFFDC2626), // Crimson
    ],
  );

  static const MamPalette dark = MamPalette(
    ground: Color(0xFF0B0F17),
    backdrop: Color(0xFF05070B),
    surface: Color(0xFF131A26),
    surfaceSubtle: Color(0xFF1C2536),
    ink: Color(0xFFF8FAFC),
    muted: Color(0xFF94A3B8),
    border: Color(0xFF243044),
    primary: Color(0xFF3B82F6),
    primarySoft: Color(0xFF172554),
    onPrimary: Color(0xFFFFFFFF),
    heroBackground: Color(0xFF1D4ED8),
    heroSettled: Color(0xFF065F46),
    success: Color(0xFF34D399),
    successSoft: Color(0xFF064E3B),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF451A03),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF450A0A),
    participantPalette: [
      Color(0xFF60A5FA), // Sky Blue
      Color(0xFF34D399), // Mint Emerald
      Color(0xFFA78BFA), // Soft Violet
      Color(0xFFFBBF24), // Warm Amber
      Color(0xFF22D3EE), // Cyan
      Color(0xFFF472B6), // Pink
      Color(0xFF818CF8), // Indigo
      Color(0xFFF87171), // Coral Red
    ],
  );

  @override
  MamPalette copyWith({
    Color? ground,
    Color? backdrop,
    Color? surface,
    Color? surfaceSubtle,
    Color? ink,
    Color? muted,
    Color? border,
    Color? primary,
    Color? primarySoft,
    Color? onPrimary,
    Color? heroBackground,
    Color? heroSettled,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    List<Color>? participantPalette,
  }) {
    return MamPalette(
      ground: ground ?? this.ground,
      backdrop: backdrop ?? this.backdrop,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      heroBackground: heroBackground ?? this.heroBackground,
      heroSettled: heroSettled ?? this.heroSettled,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      participantPalette: participantPalette ?? this.participantPalette,
    );
  }

  @override
  MamPalette lerp(ThemeExtension<MamPalette>? other, double t) {
    if (other is! MamPalette) return this;
    return MamPalette(
      ground: Color.lerp(ground, other.ground, t)!,
      backdrop: Color.lerp(backdrop, other.backdrop, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      heroBackground: Color.lerp(heroBackground, other.heroBackground, t)!,
      heroSettled: Color.lerp(heroSettled, other.heroSettled, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      participantPalette:
          t < 0.5 ? participantPalette : other.participantPalette,
    );
  }
}

extension MamPaletteContext on BuildContext {
  MamPalette get mam =>
      Theme.of(this).extension<MamPalette>() ?? MamPalette.light;
}

ThemeData buildMamLightTheme() => _buildTheme(Brightness.light, MamPalette.light);

ThemeData buildMamDarkTheme() => _buildTheme(Brightness.dark, MamPalette.dark);

ThemeData _buildTheme(Brightness brightness, MamPalette p) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: brightness,
  ).copyWith(
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primarySoft,
    secondary: p.success,
    surface: p.surface,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    outline: p.border,
    outlineVariant: p.border,
    error: p.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.ground,
    extensions: [p],
    appBarTheme: AppBarTheme(
      backgroundColor: p.ground,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: p.ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? p.surfaceSubtle : p.surface,
      isDense: true,
      labelStyle: TextStyle(color: p.muted),
      hintStyle: TextStyle(color: p.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        backgroundColor: p.surface,
        side: BorderSide(color: p.border),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return p.muted;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primarySoft;
          return p.surface;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceSubtle,
      selectedColor: p.primarySoft,
      side: BorderSide(color: p.border),
      labelStyle: TextStyle(color: p.ink, fontSize: 12.5, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dividerTheme: DividerThemeData(
      color: p.border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? p.surfaceSubtle : p.ink,
      contentTextStyle: TextStyle(color: isDark ? p.ink : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Renders edge-to-edge on phones and as a centered mobile viewport on wide web/desktop.
class MamResponsiveShell extends StatelessWidget {
  const MamResponsiveShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 520) return child;
        return ColoredBox(
          color: p.backdrop,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: p.ground,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: p.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
