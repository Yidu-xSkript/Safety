// ignore_for_file: sort_child_properties_last
// Create a pod, enter a code, wait for the partner, and the moment they arrive.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/adaptive/adaptive_widgets.dart';
import '../../core/adaptive/step_layout.dart';
import '../../core/backend/pod_backend.dart';
import '../../l10n/app_localizations.dart';
import '../rings/demo_data.dart';
import '../rings/slab.dart';
import '../rings/slab_painter.dart';
import '../today/solo_controller.dart';
import 'pod_controller.dart';

/// Calm, specific, with the next step (copy: SOUL.md → Errors).
String podErrorText(AppLocalizations l, Object e) => switch (e is PodError ? e.kind : PodErrorKind.other) {
      PodErrorKind.invalidCode => l.errInvalidCode,
      PodErrorKind.tooManyAttempts => l.errTooManyAttempts,
      PodErrorKind.alreadyInPod => l.errAlreadyInPod,
      PodErrorKind.offline => l.errOffline,
      PodErrorKind.notConfigured => l.errNotConfigured,
      PodErrorKind.other => l.genericError,
    };

const kCodeLength = 6;
// Mirrors the server's alphabet: no 0, O, 1 or I, which are too easy to misread.
final _allowed = RegExp('[A-HJ-NP-Za-hj-np-z2-9]');

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue v) => v.copyWith(text: v.text.toUpperCase());
}

/// `7K3M2P` -> `7K3 M2P`
String groupCode(String code) => code.length == kCodeLength ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

class PodChoiceScreen extends ConsumerStatefulWidget {
  const PodChoiceScreen({super.key});

  @override
  ConsumerState<PodChoiceScreen> createState() => _PodChoiceScreenState();
}

class _PodChoiceScreenState extends ConsumerState<PodChoiceScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(podProvider.notifier).createPod(); // the root then shows the waiting screen
    } catch (e) {
      if (mounted) setState(() => _error = podErrorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return StepLayout(
      children: [
        const SizedBox(height: 24),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Slab(name: '', data: demoYou, person: Person.you, diameter: 110),
              const SizedBox(width: 20),
              Slab(name: '', data: demoPartner, person: Person.partner, diameter: 110),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(l.pairTitle, style: t.headlineLarge),
        const SizedBox(height: 12),
        Text(l.pairBody, style: t.bodyLarge),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
        ],
      ],
      actions: [
        AdaptiveButton(label: l.createPod, expand: true, onPressed: _busy ? null : _create),
        const SizedBox(height: 8),
        AdaptiveButton(
          label: l.haveCode,
          kind: ButtonKind.outlined,
          expand: true,
          onPressed: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const JoinScreen())),
        ),
      ],
    );
  }
}

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _c = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(podProvider.notifier).joinPod(_c.text);
      nav.popUntil((r) => r.isFirst); // the root now shows "X is here."
    } catch (e) {
      if (mounted) setState(() => _error = podErrorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final ready = _c.text.length == kCodeLength;
    // ponytail: one field with wide letter spacing instead of six separate cells.
    return StepLayout(
      children: [
        const SizedBox(height: 8),
        Text(l.joinTitle, style: t.headlineMedium),
        const SizedBox(height: 24),
        AdaptiveTextField(
          controller: _c,
          hint: l.joinHint,
          maxLength: kCodeLength,
          autofocus: true,
          capitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: t.headlineMedium?.copyWith(letterSpacing: 6, color: Theme.of(context).colorScheme.onSurface),
          inputFormatters: [FilteringTextInputFormatter.allow(_allowed), _UpperCase()],
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => ready && !_busy ? _join() : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
        ],
      ],
      actions: [AdaptiveButton(label: l.joinButton, expand: true, onPressed: ready && !_busy ? _join : null)],
    );
  }
}

class WaitingScreen extends ConsumerStatefulWidget {
  const WaitingScreen({super.key});

  @override
  ConsumerState<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends ConsumerState<WaitingScreen> {
  bool _copied = false;
  String? _error;

  Future<void> _newCode() async {
    final l = AppLocalizations.of(context);
    try {
      await ref.read(podProvider.notifier).newCode();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = podErrorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final pod = ref.watch(podProvider).value?.pod;
    final code = pod?.inviteCode ?? '';
    final expired = pod?.inviteExpiresAt != null && pod!.inviteExpiresAt!.isBefore(ref.read(clockProvider)());

    return StepLayout(
      children: [
        const SizedBox(height: 24),
        Text(l.waitingTitle, style: t.headlineMedium),
        const SizedBox(height: 32),
        Semantics(
          label: code.split('').join(' '), // read letter by letter, not as a word
          child: ExcludeSemantics(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(groupCode(code), style: t.displayLarge?.copyWith(letterSpacing: 6, color: expired ? Theme.of(context).colorScheme.onSurfaceVariant : null)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(expired ? l.codeExpired : l.codeNote, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
        ],
      ],
      actions: expired
          ? [AdaptiveButton(label: l.newCode, expand: true, onPressed: _newCode)]
          : [
              AdaptiveButton(
                label: l.shareCode,
                expand: true,
                onPressed: () => SharePlus.instance.share(ShareParams(text: l.shareText(code))),
              ),
              const SizedBox(height: 8),
              AdaptiveButton(
                label: _copied ? l.copiedCode : l.copyCode,
                kind: ButtonKind.outlined,
                expand: true,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (mounted) setState(() => _copied = true);
                },
              ),
            ],
    );
  }
}

/// "Teo is here." for a beat, then Today. Tap to skip.
class PairedMoment extends ConsumerStatefulWidget {
  const PairedMoment({super.key});

  @override
  ConsumerState<PairedMoment> createState() => _PairedMomentState();
}

class _PairedMomentState extends ConsumerState<PairedMoment> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 1800), _done);
  }

  void _done() => ref.read(podProvider.notifier).acknowledgePaired();

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = ref.watch(podProvider).value?.pod?.partnerName ?? '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _done,
      child: AdaptiveScaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.pairedMoment(name), style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
