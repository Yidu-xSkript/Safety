// Single home for colour, type and shape values. Mirrors DESIGN.md; change both together.
// Dynamic Color is deliberately NOT used: both phones must show the same two person-hues.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Display face for numerals and headlines only (bundled variable font, see pubspec.yaml).
const kDisplayFont = 'BricolageGrotesque';

/// Colours with meaning in the Growth Ring world. `you` is always the viewer, on both phones.
@immutable
class AnchorPalette extends ThemeExtension<AnchorPalette> {
  const AnchorPalette({
    required this.you,
    required this.youDeep,
    required this.partner,
    required this.partnerDeep,
    required this.frost,
    required this.hollow,
    required this.onDeep,
  });

  final Color you; // cambium
  final Color youDeep;
  final Color partner; // sap
  final Color partnerDeep;
  final Color frost; // the scar
  final Color hollow; // not checked in
  final Color onDeep; // text on a *Deep heartwood

  static const light = AnchorPalette(
    you: Color(0xFF0A6556),
    youDeep: Color(0xFF064A3E),
    partner: Color(0xFFB8721B),
    partnerDeep: Color(0xFF7A4A0B),
    frost: Color(0xFF6E8497),
    hollow: Color(0xFF7B8781),
    onDeep: Color(0xFFF4F7F2),
  );

  static const dark = AnchorPalette(
    you: Color(0xFF4CCDB0),
    youDeep: Color(0xFF1E6B5C),
    partner: Color(0xFFE9A94A),
    partnerDeep: Color(0xFF8A5C1C),
    frost: Color(0xFF9DB3C6),
    hollow: Color(0xFF6F7E77),
    onDeep: Color(0xFFE3EBE6),
  );

  @override
  AnchorPalette copyWith({
    Color? you,
    Color? youDeep,
    Color? partner,
    Color? partnerDeep,
    Color? frost,
    Color? hollow,
    Color? onDeep,
  }) =>
      AnchorPalette(
        you: you ?? this.you,
        youDeep: youDeep ?? this.youDeep,
        partner: partner ?? this.partner,
        partnerDeep: partnerDeep ?? this.partnerDeep,
        frost: frost ?? this.frost,
        hollow: hollow ?? this.hollow,
        onDeep: onDeep ?? this.onDeep,
      );

  @override
  AnchorPalette lerp(AnchorPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AnchorPalette(
      you: l(you, other.you),
      youDeep: l(youDeep, other.youDeep),
      partner: l(partner, other.partner),
      partnerDeep: l(partnerDeep, other.partnerDeep),
      frost: l(frost, other.frost),
      hollow: l(hollow, other.hollow),
      onDeep: l(onDeep, other.onDeep),
    );
  }
}

/// The Urge screen's dimmer register: one warm hue, no pure white, no pure black.
abstract final class NightPalette {
  static const ground = Color(0xFF0A1210);
  static const ember = Color(0xFFC98A3A);
  static const lampText = Color(0xFFD9C6A5);
}

extension AnchorThemeX on BuildContext {
  AnchorPalette get palette => Theme.of(this).extension<AnchorPalette>()!;
}

// Neutral tonal steps (DESIGN.md → Colors → Neutral).
const _lichen = Color(0xFFE9EEE7);
const _spruceNight = Color(0xFF0F1A17);

ThemeData anchorTheme(Brightness brightness, {TargetPlatform? platform}) {
  final dark = brightness == Brightness.dark;
  final p = dark ? AnchorPalette.dark : AnchorPalette.light;

  final scheme = ColorScheme.fromSeed(seedColor: AnchorPalette.light.you, brightness: brightness).copyWith(
    primary: p.you,
    onPrimary: dark ? const Color(0xFF00382E) : const Color(0xFFFFFFFF),
    secondaryContainer: dark ? const Color(0xFF1F3F37) : const Color(0xFFCFE4DD),
    onSecondaryContainer: dark ? const Color(0xFFCDEDE5) : const Color(0xFF0A3A31),
    tertiary: p.frost,
    onTertiary: dark ? const Color(0xFF0F1A17) : const Color(0xFF14201C),
    surface: dark ? _spruceNight : _lichen,
    onSurface: dark ? const Color(0xFFE3EBE6) : const Color(0xFF14201C),
    onSurfaceVariant: dark ? const Color(0xFFA9B8B1) : const Color(0xFF4A5753),
    surfaceContainerLowest: dark ? const Color(0xFF0B1512) : const Color(0xFFFDFEFB),
    surfaceContainerLow: dark ? const Color(0xFF12201C) : const Color(0xFFEFF3ED),
    surfaceContainer: dark ? const Color(0xFF16241F) : const Color(0xFFF4F7F2),
    surfaceContainerHigh: dark ? const Color(0xFF1D2D27) : const Color(0xFFF9FBF7),
    surfaceContainerHighest: dark ? const Color(0xFF243730) : const Color(0xFFFDFEFB),
    outline: p.hollow,
    outlineVariant: dark ? const Color(0xFF2B3D36) : const Color(0xFFC5CEC6),
  );

  final base = ThemeData(brightness: brightness, useMaterial3: true, platform: platform);
  TextStyle? display(TextStyle? s, double size, double lineHeight, FontWeight w) =>
      s?.copyWith(
        fontFamily: kDisplayFont,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: w,
        fontVariations: [FontVariation('wght', w.value.toDouble())], // variable font: weight is an axis
      );

  final text = base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface).copyWith(
        displayLarge: display(base.textTheme.displayLarge, 56, 60, FontWeight.w700),
        headlineLarge: display(base.textTheme.headlineLarge, 32, 40, FontWeight.w600),
        headlineMedium: display(base.textTheme.headlineMedium, 28, 34, FontWeight.w600),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600),
        labelMedium: base.textTheme.labelMedium?.copyWith(letterSpacing: 0.4),
      );

  const cardRadius = BorderRadius.all(Radius.circular(20));
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    extensions: [p],
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: cardRadius),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.secondaryContainer,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
      primaryColor: p.you,
      scaffoldBackgroundColor: scheme.surface,
      barBackgroundColor: scheme.surfaceContainer,
    ),
  );
}

/// The Urge screen's own look: a dim ground, one warm hue, no pure white. Controls built from the theme
/// (buttons, text) inherit it, so the night screen needs no custom widgets.
ThemeData anchorNightTheme(ThemeData base) {
  final scheme = base.colorScheme.copyWith(
    brightness: Brightness.dark,
    primary: NightPalette.ember,
    onPrimary: NightPalette.ground,
    surface: NightPalette.ground,
    onSurface: NightPalette.lampText,
    onSurfaceVariant: NightPalette.lampText.withValues(alpha: 0.72),
    outline: NightPalette.ember.withValues(alpha: 0.6),
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: NightPalette.ground,
    textTheme: base.textTheme.apply(bodyColor: NightPalette.lampText, displayColor: NightPalette.lampText),
    cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: NightPalette.ember,
      scaffoldBackgroundColor: NightPalette.ground,
      barBackgroundColor: NightPalette.ground,
    ),
  );
}
