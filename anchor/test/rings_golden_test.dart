// Golden images for the signature component. Text renders in the test font (Ahem) so images are
// deterministic across machines; they check ring geometry, state shapes and layout, not typography.
// Update intentionally with: flutter test --update-goldens
@Tags(['golden'])
library;

import 'package:anchor/features/rings/demo_data.dart';
import 'package:anchor/features/rings/pod_header.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:anchor/features/rings/slab.dart';
import 'package:anchor/features/rings/slab_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const _h = PledgeState.held, _s = PledgeState.slipped, _u = PledgeState.unchecked;
DayRing d(PledgeState p, int done) => DayRing(pledge: p, done: done, total: 4);

// A week with a scar (day 3) and a silent day (day 5): the three states side by side.
final _mixed = SlabData(
  initial: 'M',
  daysHeld: 2,
  lastDays: [d(_h, 4), d(_h, 3), d(_s, 2), d(_h, 4), d(_u, 0), d(_h, 1), d(_h, 4)],
  today: d(_h, 2),
);
final _todaySlipped = SlabData(
  initial: 'T',
  daysHeld: 0,
  lastDays: [d(_h, 4), d(_h, 4), d(_h, 3), d(_h, 4), d(_h, 4), d(_h, 4), d(_h, 4)],
  today: d(_s, 3),
);
final _fullWeek = SlabData(
  initial: 'M',
  daysHeld: 30,
  lastDays: List.generate(7, (_) => d(_h, 4)),
  today: d(_h, 4),
);
final _newTree = SlabData(initial: 'T', daysHeld: 0, lastDays: const [], today: const DayRing(pledge: _u, done: 0, total: 0));

Widget _slabBoard() => Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          Slab(name: 'mixed', data: _mixed, person: Person.you),
          Slab(name: 'slipped today', data: _todaySlipped, person: Person.partner),
          Slab(name: 'full week', data: _fullWeek, person: Person.you),
          Slab(name: 'new tree', data: _newTree, person: Person.partner),
          Slab(name: 'pending, 3 of 4', data: demoYou, person: Person.you),
          Slab(name: 'held, 2 of 4', data: demoPartner, person: Person.partner),
        ],
      ),
    );

Widget _glyphBoard() => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final who in Person.values)
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (final s in PledgeState.values) Padding(padding: const EdgeInsets.all(8), child: RingGlyph(state: s, person: who)),
              for (final s in PledgeState.values) Padding(padding: const EdgeInsets.all(8), child: RingGlyph(state: s, person: who, size: 40)),
            ]),
        ],
      ),
    );

Widget _header() => Padding(
      padding: const EdgeInsets.all(16),
      child: PodHeader(youName: 'Mika', partnerName: 'Teo', you: demoYou, partner: demoPartner, podStreak: 14),
    );

Future<void> golden(WidgetTester t, Widget w, String file,
    {Size size = const Size(440, 460), Brightness brightness = Brightness.light, double textScale = 1}) async {
  t.view.devicePixelRatio = 2;
  t.view.physicalSize = size * 2; // `size` is in logical dp
  addTearDown(t.view.reset);
  await t.pumpWidget(harness(Scaffold(body: SingleChildScrollView(child: w)), brightness: brightness, textScale: textScale));
  await t.pumpAndSettle();
  await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/$file.png'));
}

void main() {
  testWidgets('slabs, light', (t) => golden(t, _slabBoard(), 'slabs_light', size: const Size(380, 560)));
  testWidgets('slabs, dark', (t) => golden(t, _slabBoard(), 'slabs_dark', size: const Size(380, 560), brightness: Brightness.dark));
  testWidgets('glyphs, light', (t) => golden(t, _glyphBoard(), 'glyphs_light', size: const Size(380, 190)));
  testWidgets('glyphs, dark', (t) => golden(t, _glyphBoard(), 'glyphs_dark', size: const Size(380, 190), brightness: Brightness.dark));
  testWidgets('pod header, 390dp, light', (t) => golden(t, _header(), 'pod_header_light', size: const Size(390, 440)));
  testWidgets('pod header, 390dp, dark', (t) => golden(t, _header(), 'pod_header_dark', size: const Size(390, 440), brightness: Brightness.dark));
  testWidgets('pod header, 320dp wide', (t) => golden(t, _header(), 'pod_header_320', size: const Size(320, 440)));
  testWidgets('pod header, 200% text', (t) => golden(t, _header(), 'pod_header_2x', size: const Size(390, 600), textScale: 2));

  testWidgets('slab announces the whole picture and nothing else', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(harness(Scaffold(body: Slab(name: 'Mika', data: _mixed, person: Person.you))));
    expect(
      find.bySemanticsLabel(
          'Mika: 2 days held. Today: habits 2 of 4, pledge held. Last days: held, held, slipped, held, not checked in, held, held.'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
