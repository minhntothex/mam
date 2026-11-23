import 'package:material_ui/material_ui.dart';

// Mâm — Fresh Pastel Fintech Design Tokens
// Single light pastel theme with verified WCAG AA/AAA contrast.

const TextStyle kTabularStyle = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Print-safe palette for exported PNG Receipt Cards & VietQR cards.
/// Always renders on crisp white paper so bank apps scan reliably from Zalo/Messenger.
abstract final class MamReceiptColors {
  static const Color paper = Color(0xFFFFFFFF);
  static const Color subtle = Color(0xFFF7F8FC);
  static const Color ink = Color(0xFF1E293B);
  static const Color muted = Color(0xFF56637A);
  static const Color border = Color(0xFFE6EAF2);
  static const Color primary = Color(0xFF2F5EE5);
  static const Color success = Color(0xFF146E52);
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
    required this.primaryFill,
    required this.primarySoft,
    required this.onPrimary,
    required this.heroBackground,
    required this.onHero,
    required this.heroSettled,
    required this.onHeroSettled,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.onDanger,
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
  final Color primaryFill;
  final Color primarySoft;
  final Color onPrimary;
  final Color heroBackground;
  final Color onHero;
  final Color heroSettled;
  final Color onHeroSettled;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color onDanger;
  final List<Color> participantPalette;

  Color participantColor(int index) =>
      participantPalette[index % participantPalette.length];

  static const MamPalette light = MamPalette(
    ground: Color(0xFFF7F8FC),
    backdrop: Color(0xFFEAF0FA),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF0F3F9),
    ink: Color(0xFF1E293B),
    muted: Color(0xFF56637A),
    border: Color(0xFFE6EAF2),
    primary: Color(0xFF2F5EE5),
    primaryFill: Color(0xFF96BFFF),
    primarySoft: Color(0xFFEDF3FF),
    onPrimary: Color(0xFF0D2247),
    heroBackground: Color(0xFFFFE9A3),
    onHero: Color(0xFF3B2804),
    heroSettled: Color(0xFFBDF2DC),
    onHeroSettled: Color(0xFF0A3A2B),
    success: Color(0xFF146E52),
    successSoft: Color(0xFFDDF7EC),
    warning: Color(0xFF7F4B00),
    warningSoft: Color(0xFFFFF2BE),
    danger: Color(0xFFB42343),
    dangerSoft: Color(0xFFFFE2E8),
    onDanger: Color(0xFFFFFFFF),
    participantPalette: [
      Color(0xFF4F86F7), // Periwinkle Pastel
      Color(0xFF2EB88A), // Mint Pastel
      Color(0xFF8C6FF7), // Lavender Pastel
      Color(0xFFE0912B), // Peach-Butter Pastel
      Color(0xFF24A6BD), // Aqua Pastel
      Color(0xFFE36496), // Sakura Pink Pastel
      Color(0xFF6A78F2), // Soft Indigo Pastel
      Color(0xFFE56B70), // Coral Pastel
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
    Color? primaryFill,
    Color? primarySoft,
    Color? onPrimary,
    Color? heroBackground,
    Color? onHero,
    Color? heroSettled,
    Color? onHeroSettled,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? onDanger,
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
      primaryFill: primaryFill ?? this.primaryFill,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      heroBackground: heroBackground ?? this.heroBackground,
      onHero: onHero ?? this.onHero,
      heroSettled: heroSettled ?? this.heroSettled,
      onHeroSettled: onHeroSettled ?? this.onHeroSettled,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      onDanger: onDanger ?? this.onDanger,
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
      primaryFill: Color.lerp(primaryFill, other.primaryFill, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      heroBackground: Color.lerp(heroBackground, other.heroBackground, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      heroSettled: Color.lerp(heroSettled, other.heroSettled, t)!,
      onHeroSettled: Color.lerp(onHeroSettled, other.onHeroSettled, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      participantPalette:
          t < 0.5 ? participantPalette : other.participantPalette,
    );
  }
}

extension MamPaletteContext on BuildContext {
  MamPalette get mam =>
      Theme.of(this).extension<MamPalette>() ?? MamPalette.light;
}

ThemeData buildMamTheme() {
  const p = MamPalette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: Brightness.light,
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
    onError: p.onDanger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.ground,
    extensions: const [p],
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
      fillColor: p.surface,
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
        backgroundColor: p.primaryFill,
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
          if (states.contains(WidgetState.selected)) return p.onPrimary;
          return p.muted;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primaryFill;
          return p.surface;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
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
      backgroundColor: p.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
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
