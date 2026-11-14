import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

/// The "Urge" shortcut on the app icon (Android long-press shortcut, iOS Home Screen quick action):
/// two actions from the home screen to the grounding screen.
abstract class AppShortcuts {
  Future<void> init(void Function() onUrge);
}

class NoShortcuts implements AppShortcuts {
  @override
  Future<void> init(void Function() onUrge) async {}
}

class QuickActionShortcuts implements AppShortcuts {
  @override
  Future<void> init(void Function() onUrge) async {
    try {
      const qa = QuickActions();
      await qa.initialize((type) {
        if (type == 'urge') onUrge();
      });
      // ponytail: fixed English title until the app is localised; "Urge" alone says nothing to a bystander.
      await qa.setShortcutItems(const [ShortcutItem(type: 'urge', localizedTitle: 'Urge')]);
    } catch (_) {
      // no platform channel (tests, desktop): shortcuts are a convenience, never a requirement
    }
  }
}

final shortcutsProvider = Provider<AppShortcuts>((_) => QuickActionShortcuts());
