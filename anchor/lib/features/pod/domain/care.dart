// Small pure rules for caring for each other: the sync chip, the once-a-day hello, the daily reminder time.
import '../../rings/ring_model.dart';

enum SyncState { inSync, waitingOnPartner, none }

/// "In sync" = both of you have checked in today or yesterday. Otherwise, if it is your partner who has not,
/// "Waiting on Teo" (neutral: never "behind", never a count of missed days). If only you are missing, no chip.
SyncState syncState({
  required PledgeState? meToday,
  required PledgeState? meYesterday,
  required PledgeState? partnerToday,
  required PledgeState? partnerYesterday,
}) {
  final partnerRecent = partnerToday != null || partnerYesterday != null;
  final meRecent = meToday != null || meYesterday != null;
  if (!partnerRecent) return SyncState.waitingOnPartner;
  return meRecent ? SyncState.inSync : SyncState.none;
}

/// The hello is offered only in the evening (from 18:00), only while they have not checked in today, and once a day.
bool nudgeAvailable({required PledgeState? partnerToday, required bool sentToday, required DateTime now}) =>
    partnerToday == null && !sentToday && now.hour >= 18;

/// The next moment the daily reminder should fire. If you have already checked in today, today's is skipped.
DateTime nextReminder(DateTime now, int hour, int minute, {required bool skipToday}) {
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now) || skipToday) next = DateTime(next.year, next.month, next.day + 1, hour, minute);
  return next;
}

const kDefaultReminderHour = 21;
const kDefaultReminderMinute = 30;
