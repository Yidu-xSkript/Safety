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
  const AdaptivePage({super.key, required this.title, required this.onUrge, required this.children, this.large = true});

  final String title;
  final VoidCallback onUrge;
  final List<Widget> children;

  /// Android: a large collapsing app bar (History, Pod) or the small pinned one (Today, to keep the pledge above the fold).
  /// iOS always uses a large title, as top-level tab screens do.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final ios = isIOS(context);
    final body = SliverLayoutBuilder(
      builder: (context, c) {
        final pad = math.max(kGutter, (c.crossAxisExtent - kMaxContentWidth) / 2);
        return SliverPadding(
          // Android: clear the extended Urge FAB (56dp + 16dp margin) so the last card scrolls fully above it.
          padding: EdgeInsets.fromLTRB(pad, 8, pad, ios ? 32 : 104),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        );
      },
    );

    if (ios) {
      return CupertinoPageScaffold(
        // Material widgets (checkbox rows, text fields) need a Material ancestor even on iOS.
        child: Material(
          type: MaterialType.transparency,
          child: CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(title),
                trailing: UrgeNavButton(onPressed: onUrge),
              ),
              SliverSafeArea(top: false, sliver: body),
            ],
          ),
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        large ? SliverAppBar.large(title: Text(title)) : SliverAppBar(title: Text(title), pinned: true),
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
