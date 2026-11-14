// Guards DESIGN.md's contrast claims: text >= 4.5:1, graphics that carry meaning >= 3:1.
import 'package:anchor/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final b in Brightness.values) {
    final theme = anchorTheme(b);
    final s = theme.colorScheme;
    final p = theme.extension<AnchorPalette>()!;
    final grounds = {'surface': s.surface, 'card': s.surfaceContainer, 'sheet': s.surfaceContainerHigh};

    group(b.name, () {
      for (final MapEntry(key: name, value: bg) in grounds.entries) {
        test('text on $name', () {
          expect(ratio(s.onSurface, bg), greaterThanOrEqualTo(4.5), reason: 'onSurface');
          expect(ratio(s.onSurfaceVariant, bg), greaterThanOrEqualTo(4.5), reason: 'onSurfaceVariant');
          expect(ratio(s.primary, bg), greaterThanOrEqualTo(4.5), reason: 'primary as text/link');
        });
        test('meaningful graphics on $name', () {
          for (final (label, c) in [('you', p.you), ('partner', p.partner), ('frost', p.frost), ('hollow', p.hollow)]) {
            expect(ratio(c, bg), greaterThanOrEqualTo(3.0), reason: label);
          }
        });
      }

      test('primary button text', () => expect(ratio(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5)));
      test('selected nav item', () => expect(ratio(s.onSecondaryContainer, s.secondaryContainer), greaterThanOrEqualTo(4.5)));
      test('initial on heartwood', () {
        expect(ratio(p.onDeep, p.youDeep), greaterThanOrEqualTo(4.5));
        expect(ratio(p.onDeep, p.partnerDeep), greaterThanOrEqualTo(4.5));
      });
    });
  }

  test('night register: lamp text and ember readable on night ground; no pure white or black', () {
    expect(ratio(NightPalette.lampText, NightPalette.ground), greaterThanOrEqualTo(4.5));
    expect(ratio(NightPalette.ember, NightPalette.ground), greaterThanOrEqualTo(4.5));
    expect(NightPalette.lampText, isNot(const Color(0xFFFFFFFF)));
    expect(NightPalette.ground, isNot(const Color(0xFF000000)));
  });

  test('dark theme avoids pure white text and pure black ground', () {
    final s = anchorTheme(Brightness.dark).colorScheme;
    expect(s.onSurface, isNot(const Color(0xFFFFFFFF)));
    expect(s.surface, isNot(const Color(0xFF000000)));
  });
}
