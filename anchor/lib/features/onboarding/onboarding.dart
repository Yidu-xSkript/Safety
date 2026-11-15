// ignore_for_file: sort_child_properties_last
// Welcome -> name -> habits. Each step is a real route, so Android predictive back and the iOS edge swipe just work.
// Phase 2 adds create/join pod after habits.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive/adaptive_widgets.dart';
import '../../core/adaptive/step_layout.dart';
import '../../l10n/app_localizations.dart';
import '../pod/email_flow.dart';
import '../rings/demo_data.dart';
import '../rings/slab.dart';
import '../rings/slab_painter.dart';
import '../today/solo_controller.dart';

const kMaxHabits = 8;
const kMaxNameLength = 24;
const kMaxHabitLength = 40;

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return StepLayout(
      children: [
        const SizedBox(height: 24),
        // Decorative: the two-slab idea in one glance. Synthetic data, hidden from screen readers.
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Slab(name: '', data: demoYou, person: Person.you, diameter: 130),
              const SizedBox(width: 24),
              Slab(name: '', data: demoPartner, person: Person.partner, diameter: 130),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Text(l.welcomeTitle, style: t.headlineLarge),
        const SizedBox(height: 12),
        Text(l.welcomeBody, style: t.bodyLarge),
      ],
      actions: [
        Text(l.notTreatment, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        AdaptiveButton(
          label: l.getStarted,
          expand: true,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NameScreen())),
        ),
        AdaptiveButton(
          label: l.restoreAction,
          kind: ButtonKind.text,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RestoreScreen())),
        ),
      ],
    );
  }
}

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _next() {
    final name = _c.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HabitsScreen(name: name)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return StepLayout(
      children: [
        const SizedBox(height: 8),
        Text(l.nameTitle, style: t.headlineMedium),
        const SizedBox(height: 24),
        AdaptiveTextField(
          controller: _c,
          hint: l.nameHint,
          maxLength: kMaxNameLength,
          autofocus: true,
          capitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _next(),
        ),
        const SizedBox(height: 12),
        Text(l.nameHelper, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
      actions: [AdaptiveButton(label: l.continueLabel, expand: true, onPressed: _c.text.trim().isEmpty ? null : _next)],
    );
  }
}

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key, required this.name});

  final String name;

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  final _custom = TextEditingController();
  final _selected = <String>[]; // titles, in the order the user ticked them
  final _extra = <String>[]; // custom titles added so far
  bool _adding = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _toggle(String title, bool on) => setState(() => on ? _selected.add(title) : _selected.remove(title));

  void _addCustom() {
    final t = _custom.text.trim();
    if (t.isEmpty || _selected.length >= kMaxHabits) return;
    setState(() {
      if (!_extra.contains(t)) _extra.add(t);
      if (!_selected.contains(t)) _selected.add(t);
      _custom.clear();
      _adding = false;
    });
  }

  Future<void> _finish(List<String> titles) async {
    final controller = ref.read(soloProvider.notifier); // read before this screen is popped and disposed
    final name = widget.name;
    Navigator.of(context).popUntil((r) => r.isFirst); // the root swaps to the shell once state is saved
    await controller.completeOnboarding(name, titles);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final presets = [l.habitMorningPrayer, l.habitNightPrayer, l.habitWorkout, l.habitReading, l.habitPhoneAway];
    final all = [...presets, ..._extra];
    final full = _selected.length >= kMaxHabits;

    return StepLayout(
      children: [
        const SizedBox(height: 8),
        Text(l.habitsTitle, style: t.headlineMedium),
        const SizedBox(height: 8),
        Text(l.habitsBody, style: t.bodyLarge),
        const SizedBox(height: 16),
        for (final title in all)
          CheckboxListTile.adaptive(
            activeColor: Theme.of(context).colorScheme.primary, // iOS defaults to system blue
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(title),
            value: _selected.contains(title),
            onChanged: (v) => _toggle(title, v ?? false),
          ),
        const SizedBox(height: 8),
        if (_adding) ...[
          AdaptiveTextField(
            controller: _custom,
            hint: l.addHabitHint,
            maxLength: kMaxHabitLength,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addCustom(),
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: AdaptiveButton(label: l.add, kind: ButtonKind.text, onPressed: _addCustom)),
        ] else
          Align(
            alignment: Alignment.centerLeft,
            child: AdaptiveButton(label: l.addYourOwn, kind: ButtonKind.text, onPressed: full ? null : () => setState(() => _adding = true)),
          ),
        if (full) Text(l.habitsLimit, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
      actions: [
        AdaptiveButton(label: l.startToday, expand: true, onPressed: () => _finish(List.of(_selected))),
        AdaptiveButton(label: l.justThePledge, kind: ButtonKind.text, onPressed: () => _finish(const [])),
      ],
    );
  }
}
