// The hard moment: opens instantly, tells the partner, and walks you through three quiet minutes.
// Night register (DESIGN.md): dim ground, one warm hue, no pure white, nothing faster than a breath, no flashing.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/backend/pod_backend.dart' show ReplyInfo;
import '../../core/adaptive/adaptive_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../pod/pod_controller.dart';
import 'contact.dart';
import 'grounding.dart';
import 'replies.dart';

/// What the screen hands back when it closes.
enum UrgeResult { done, slipped }

/// Feature flag: the curated crisis-resource list is a launch blocker owned by the product owner
/// (docs/SECURITY.md). Nothing is shown, and no number or link is invented, until it exists.
const kShowCrisisResources = false;

class UrgeScreen extends ConsumerStatefulWidget {
  const UrgeScreen({super.key});

  @override
  ConsumerState<UrgeScreen> createState() => _UrgeScreenState();
}

class _UrgeScreenState extends ConsumerState<UrgeScreen> with SingleTickerProviderStateMixin {
  late final String _id;
  Timer? _tick;
  Timer? _close;
  AnimationController? _breath;
  int _elapsed = 0;
  bool _retracted = false;

  @override
  void initState() {
    super.initState();
    // First thing, before the first frame: the ping is queued now and goes out at once when online.
    _id = ref.read(podProvider.notifier).beginUrge();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce && _breath != null) {
      _breath!.dispose();
      _breath = null;
    } else if (!reduce && _breath == null) {
      _breath = AnimationController(vsync: this, duration: const Duration(seconds: kBreathCycleSeconds))..repeat();
    }
  }

  void _onTick() {
    final before = breathPhase(_elapsed);
    setState(() => _elapsed++);
    // Without motion the breath is carried by words and a soft tap at each turn.
    if (_breath == null && breathPhase(_elapsed) != before) HapticFeedback.selectionClick();
    if (groundingDone(_elapsed)) {
      _tick?.cancel();
      _breath?.stop(); // the ring rests; nothing keeps animating behind the end screen
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _close?.cancel();
    _breath?.dispose();
    super.dispose();
  }

  void _mistake(bool paired) {
    ref.read(podProvider.notifier).retractUrge(_id);
    _tick?.cancel();
    _breath?.stop();
    if (!paired) return Navigator.of(context).pop(UrgeResult.done);
    setState(() => _retracted = true);
    _close = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pop(UrgeResult.done);
    });
  }

  void _finish(String outcome, UrgeResult result) {
    ref.read(podProvider.notifier).finishUrge(_id, outcome);
    Navigator.of(context).pop(result);
  }

  void _moreTime() {
    setState(() => _elapsed = 0);
    _breath?.repeat();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = anchorNightTheme(anchorTheme(Brightness.dark, platform: Theme.of(context).platform));
    final pod = ref.watch(podProvider).value;
    final partner = pod?.pod?.partnerName ?? '';
    final paired = pod?.active ?? false;
    final queued = pod?.pendingKeys.contains('u:$_id') ?? false;
    final reply = pod?.replies.where((r) => !r.fromMe && r.urgeId == _id).firstOrNull;
    final done = groundingDone(_elapsed);
    final t = theme.textTheme;

    return Theme(
      data: theme,
      child: PopScope(
        // Back always works. Leaving early records nothing: the partner already knows, and "mistake" is explicit.
        child: AdaptiveScaffold(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    if (_retracted)
                      Expanded(child: Center(child: Text(l.urgeMistakeSent, style: t.headlineMedium, textAlign: TextAlign.center)))
                    else ...[
                      if (paired) Text(queued ? l.urgeQueued(partner) : l.urgeToldYes(partner), style: t.titleLarge, textAlign: TextAlign.center),
                      if (paired) const SizedBox(height: 4),
                      Text(l.urgeStay, style: t.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                      Expanded(child: _centered(done ? _end(l, t) : _grounding(l, t))),
                      if (reply != null) _replyCard(l, t, partner, reply),
                      const SizedBox(height: 8),
                      const ContactButtons(),
                      if (paired && !done) AdaptiveButton(label: l.urgeMistake, kind: ButtonKind.text, onPressed: () => _mistake(paired)),
                      if (kShowCrisisResources) AdaptiveButton(label: l.urgeHelp, kind: ButtonKind.text, onPressed: () {}),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Centred when it fits; scrolls when large text or a small phone makes it taller than the space. Never clipped.
  Widget _centered(Widget child) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          child: ConstrainedBox(constraints: BoxConstraints(minHeight: c.maxHeight), child: Center(child: child)),
        ),
      );

  Widget _grounding(AppLocalizations l, TextTheme t) {
    final steps = [l.urgeStep1, l.urgeStep2, l.urgeStep3];
    final inhale = breathPhase(_elapsed) == BreathPhase.inhale;
    final reduce = _breath == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // One slow ring. Reduced motion: it holds still and the words carry the breath.
        SizedBox(
          width: 220,
          height: 220,
          child: reduce
              ? CustomPaint(painter: _BreathPainter(0.55, NightPalette.ember))
              : AnimatedBuilder(
                  animation: _breath!,
                  builder: (_, _) => CustomPaint(
                    painter: _BreathPainter(breathScale(_breath!.value * kBreathCycleSeconds), NightPalette.ember),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(inhale ? l.breathIn : l.breathOut, style: t.titleLarge),
        const SizedBox(height: 32),
        Semantics(
          liveRegion: true,
          child: AnimatedSwitcher(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 600),
            child: Text(
              steps[stepIndex(_elapsed)],
              key: ValueKey(stepIndex(_elapsed)),
              style: t.headlineLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(countdown(_elapsed), style: t.labelLarge?.copyWith(color: NightPalette.lampText.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _end(AppLocalizations l, TextTheme t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.urgeEndTitle, style: t.headlineLarge, textAlign: TextAlign.center),
        const SizedBox(height: 32),
        AdaptiveButton(label: l.urgeEndPassed, expand: true, onPressed: () => _finish('passed', UrgeResult.done)),
        const SizedBox(height: 8),
        AdaptiveButton(label: l.urgeEndMore, kind: ButtonKind.outlined, expand: true, onPressed: _moreTime),
        const SizedBox(height: 8),
        AdaptiveButton(label: l.urgeEndSlipped, kind: ButtonKind.outlined, expand: true, onPressed: () => _finish('slipped', UrgeResult.slipped)),
      ],
    );
  }

  Widget _replyCard(AppLocalizations l, TextTheme t, String partner, ReplyInfo r) {
    final template = ReplyTemplate.fromKey(r.template);
    if (template == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(alignment: Alignment.centerLeft, child: Text(l.urgeReplyLine(partner, replyText(l, template)), style: t.titleLarge)),
      ),
    );
  }
}

/// Three flat rings, the middle one breathing: radius follows [scale] (0 smallest .. 1 fullest). No glow, no gradient.
class _BreathPainter extends CustomPainter {
  _BreathPainter(this.scale, this.color);

  final double scale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final max = math.min(size.width, size.height) / 2 - 4;
    final r = max * (0.62 + 0.38 * scale);
    for (final (f, w, a) in const [(1.0, 6.0, 1.0), (0.82, 4.0, 0.55), (0.64, 3.0, 0.3)]) {
      canvas.drawCircle(
        c,
        r * f,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = color.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_BreathPainter old) => old.scale != scale || old.color != color;
}
