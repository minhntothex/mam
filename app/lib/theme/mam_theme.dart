import 'package:material_ui/material_ui.dart';

abstract final class MamColors {
  static const Color paper = Color(0xFFFAF8F5);
  static const Color desk = Color(0xFFEBE6DD);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1F1D1A);
  static const Color muted = Color(0xFF6F6A63);
  static const Color border = Color(0xFFE5DFD5);

  static const Color accent = Color(0xFFC84B31);
  static const Color accentSoft = Color(0xFFFCEEE9);

  static const Color sage = Color(0xFF2E7D5B);
  static const Color sageSoft = Color(0xFFE8F4EE);

  static const Color amber = Color(0xFFB45309);
  static const Color amberSoft = Color(0xFFFEF3C7);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);

  static const List<Color> participantPalette = [
    Color(0xFFC84B31), // Terracotta
    Color(0xFF2563EB), // Cobalt
    Color(0xFF2E7D5B), // Sage
    Color(0xFF9333EA), // Plum
    Color(0xFFD97706), // Ochre
    Color(0xFF0891B2), // Teal
    Color(0xFFDB2777), // Berry
    Color(0xFF4F46E5), // Indigo
  ];

  static Color participantColor(int index) {
    return participantPalette[index % participantPalette.length];
  }
}

ThemeData buildMamTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: MamColors.accent,
      surface: MamColors.paper,
    ).copyWith(
      primary: MamColors.accent,
      onPrimary: Colors.white,
      secondary: MamColors.sage,
      surface: MamColors.paper,
      onSurface: MamColors.ink,
      outline: MamColors.border,
    ),
    scaffoldBackgroundColor: MamColors.paper,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: MamColors.paper,
      foregroundColor: MamColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: MamColors.ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: MamColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MamColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MamColors.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: MamColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: MamColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: MamColors.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MamColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MamColors.ink,
        side: const BorderSide(color: MamColors.border),
        backgroundColor: MamColors.card,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: MamColors.border,
      thickness: 1,
      space: 1,
    ),
  );
}

const TextStyle kTabularStyle = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Renders edge-to-edge on phones and as a centered mobile canvas on wide web/desktop.
class MamResponsiveShell extends StatelessWidget {
  const MamResponsiveShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 520) return child;
        return ColoredBox(
          color: MamColors.desk,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: MamColors.paper,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: MamColors.border, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A1F1D1A),
                      blurRadius: 32,
                      offset: Offset(0, 12),
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
