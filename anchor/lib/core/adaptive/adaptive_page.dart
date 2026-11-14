// The one place a top-level screen picks Material vs Cupertino chrome.
// Android: SliverAppBar (the Urge FAB lives in the shell). iOS: large-title bar with Urge as its trailing action.
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

bool isIOS(BuildContext context) => Theme.of(context).platform == TargetPlatform.iOS;

/// Content never grows wider than this; on tablets and iPad it is centred.
const kMaxContentWidth = 600.0;
const kGutter = 16.0;

class AdaptivePage extends StatelessWidget {
  const AdaptivePage({super.key, required this.title, required this.onUrge, required this.children});

  final String title;
  final VoidCallback onUrge;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final body = SliverLayoutBuilder(
      builder: (context, c) {
        final pad = math.max(kGutter, (c.crossAxisExtent - kMaxContentWidth) / 2);
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        );
      },
    );

    if (isIOS(context)) {
      return CupertinoPageScaffold(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(title),
              trailing: UrgeNavButton(onPressed: onUrge),
            ),
            SliverSafeArea(top: false, sliver: body),
          ],
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(title: Text(title)),
        body,
      ],
    );
  }
}

/// iOS Urge entry: a trailing toolbar action, 44pt minimum.
class UrgeNavButton extends StatelessWidget {
  const UrgeNavButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.urgeTooltip,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.hand_raised, size: 20),
            const SizedBox(width: 4),
            Text(l.urge),
          ],
        ),
      ),
    );
  }
}
