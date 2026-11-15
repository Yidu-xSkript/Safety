import '../../l10n/app_localizations.dart';

/// Prepared words only: no free text, so the channel can never be used to hurt. Keys match the server's
/// `encouragements.template_key` check constraint.
enum ReplyTemplate {
  here('here'),
  callMe('call_me'),
  walk('walk'),
  proud('proud'),
  thankYou('thank_you'),
  newRing('new_ring'),
  hello('hello'); // the once-a-day nudge; never offered as a reply

  const ReplyTemplate(this.key);

  final String key;

  static ReplyTemplate? fromKey(String key) {
    for (final t in values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

/// What a partner can answer to "reaching out", and to "posted an update". Ordered: the first is the gentlest.
const urgeReplies = [ReplyTemplate.here, ReplyTemplate.callMe, ReplyTemplate.walk, ReplyTemplate.proud];
const slipReplies = [ReplyTemplate.thankYou, ReplyTemplate.newRing, ReplyTemplate.callMe, ReplyTemplate.proud];

String replyText(AppLocalizations l, ReplyTemplate t) => switch (t) {
      ReplyTemplate.here => l.replyHere,
      ReplyTemplate.callMe => l.replyCallMe,
      ReplyTemplate.walk => l.replyWalk,
      ReplyTemplate.proud => l.replyProud,
      ReplyTemplate.thankYou => l.replyThankYou,
      ReplyTemplate.newRing => l.replyNewRing,
      ReplyTemplate.hello => l.replyHello,
    };
