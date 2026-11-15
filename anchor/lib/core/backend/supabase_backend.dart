// Supabase implementation of PodBackend. Schema and rules: supabase/migrations/0001_init.sql.
// NOT yet exercised against a live project (none exists yet): the SQL is tested, this client is not.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/rings/ring_model.dart';
import '../../features/today/domain/models.dart';
import '../local_day.dart';
import 'pod_backend.dart';

const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get supabaseConfigured => kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;

class SupabaseBackend implements PodBackend {
  SupabaseClient get _c => Supabase.instance.client;

  @override
  bool get configured => true;

  /// Server answered with an error we know -> a calm kind. No answer at all -> offline.
  PodError _map(Object e) {
    if (e is PodError) return e;
    if (e is PostgrestException) {
      final m = '${e.message} ${e.details ?? ''}';
      if (m.contains('already_in_pod')) return const PodError(PodErrorKind.alreadyInPod);
      if (m.contains('too_many_attempts')) return const PodError(PodErrorKind.tooManyAttempts);
      if (m.contains('invalid_code')) return const PodError(PodErrorKind.invalidCode);
      if (const {'502', '503', '504'}.contains(e.code)) return const PodError(PodErrorKind.offline);
      return const PodError(PodErrorKind.other);
    }
    if (e is AuthRetryableFetchException) return const PodError(PodErrorKind.offline);
    if (e is AuthException) return const PodError(PodErrorKind.other);
    return const PodError(PodErrorKind.offline); // socket, DNS, timeout, TLS: the phone could not reach the server
  }

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> ensureSignedIn() => _guard(() async {
        if (_c.auth.currentSession == null) await _c.auth.signInAnonymously();
      });

  @override
  Future<void> setProfile(String name, int utcOffsetMin) =>
      _guard(() => _c.rpc('set_profile', params: {'p_name': name, 'p_offset': utcOffsetMin}));

  PodInfo? _pod(List rows) {
    if (rows.isEmpty) return null;
    final r = rows.first as Map<String, dynamic>;
    return PodInfo(
      podId: r['pod_id'] as String,
      status: PodStatus.values.byName(r['status'] as String),
      inviteCode: r['invite_code'] as String?,
      inviteExpiresAt: r['invite_expires_at'] == null ? null : DateTime.parse(r['invite_expires_at'] as String),
      partnerId: r['partner_id'] as String?,
      partnerName: r['partner_name'] as String?,
    );
  }

  @override
  Future<PodInfo?> myPod() => _guard(() async => _pod(await _c.rpc('my_pod') as List));

  @override
  Future<PodInfo> createPod() => _guard(() async {
        final rows = await _c.rpc('create_pod') as List;
        final r = rows.first as Map<String, dynamic>;
        return PodInfo(
          podId: r['out_pod'] as String,
          status: PodStatus.open,
          inviteCode: r['out_code'] as String,
          inviteExpiresAt: DateTime.parse(r['out_expires'] as String),
        );
      });

  @override
  Future<void> joinPod(String code) => _guard(() async {
        final r = await _c.rpc('join_pod', params: {'code': code}) as Map<String, dynamic>;
        if (r['error'] == 'invalid_code') throw const PodError(PodErrorKind.invalidCode);
      });

  @override
  Future<void> leavePod() => _guard(() => _c.rpc('leave_pod'));

  @override
  Future<SoloData> fetchPartner(PodInfo pod, DateTime today) => _guard(() => _person(pod.partnerId!, pod.partnerName ?? '', today));

  @override
  Future<SoloData> fetchMine(DateTime today) => _guard(() async {
        final me = _c.auth.currentUser!.id;
        final row = await _c.from('profiles').select('display_name').eq('id', me).maybeSingle();
        return _person(me, (row?['display_name'] as String?) ?? '', today);
      });

  /// One person's name, habits, pledges and ticks since [kHistoryDays] ago, shaped like [SoloData].
  Future<SoloData> _person(String id, String name, DateTime today) async {
    final since = dayKey(addDays(today, -kHistoryDays));
    final cis = await _c.from('check_ins').select('local_date,status,note,updated_at').eq('user_id', id).gte('local_date', since);
    final habits = await _c.from('habits').select('id,title,created_day,archived_day').eq('user_id', id);
    final logs = await _c.from('habit_logs').select('habit_id,local_date').eq('user_id', id).gte('local_date', since);

    final checkIns = {
      for (final r in cis)
        r['local_date'] as String: CheckIn(
          state: PledgeState.values.byName(r['status'] as String),
          at: DateTime.parse(r['updated_at'] as String).toLocal(),
          note: r['note'] as String?,
        ),
    };
    final ticked = <String, Set<String>>{};
    for (final r in logs) {
      (ticked[r['local_date'] as String] ??= {}).add(r['habit_id'] as String);
    }
    final habitList = [
      for (final r in habits)
        Habit(
          id: r['id'] as String,
          title: r['title'] as String,
          createdDay: parseDayKey(r['created_day'] as String),
          archivedDay: r['archived_day'] == null ? null : parseDayKey(r['archived_day'] as String),
        ),
    ];
    // First day with anything on record; days before it did not happen for them.
    final days = [...checkIns.keys.map(parseDayKey), ...habitList.map((h) => h.createdDay)]..sort();
    return SoloData(name: name, onboarded: true, startDay: days.isEmpty ? null : days.first, habits: habitList, checkIns: checkIns, logs: ticked);
  }

  @override
  Future<String?> accountEmail() => _guard(() async {
        final u = _c.auth.currentUser;
        final e = u?.email;
        return (u == null || u.isAnonymous || e == null || e.isEmpty) ? null : e;
      });

  /// A code that does not verify is the person's mistake, not a crash.
  Future<void> _verify(Future<Object?> Function() f) async {
    try {
      await f();
    } on AuthRetryableFetchException {
      throw const PodError(PodErrorKind.offline);
    } on AuthException {
      throw const PodError(PodErrorKind.invalidOtp);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> requestEmailLink(String email) async {
    try {
      await _c.auth.updateUser(UserAttributes(email: email));
    } on AuthException catch (e) {
      if (e is AuthRetryableFetchException) throw const PodError(PodErrorKind.offline);
      if (e.code == 'email_exists' || e.message.toLowerCase().contains('already')) throw const PodError(PodErrorKind.emailInUse);
      if (e.code == 'over_email_send_rate_limit' || e.statusCode == '429') throw const PodError(PodErrorKind.tooManyAttempts);
      throw const PodError(PodErrorKind.other);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> confirmEmailLink(String email, String code) =>
      _verify(() => _c.auth.verifyOTP(email: email, token: code, type: OtpType.emailChange));

  @override
  Future<void> requestSignIn(String email) async {
    try {
      await _c.auth.signInWithOtp(email: email, shouldCreateUser: false);
    } on AuthException catch (e) {
      if (e is AuthRetryableFetchException) throw const PodError(PodErrorKind.offline);
      if (e.code == 'over_email_send_rate_limit' || e.statusCode == '429') throw const PodError(PodErrorKind.tooManyAttempts);
      throw const PodError(PodErrorKind.other);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> confirmSignIn(String email, String code) => _verify(() => _c.auth.verifyOTP(email: email, token: code, type: OtpType.email));

  @override
  Future<PodActivity> fetchActivity(PodInfo pod, DateTime now) => _guard(() async {
        final me = _c.auth.currentUser!.id;
        final fresh = now.subtract(kUrgeFreshness).toUtc().toIso8601String();
        final urges = await _c
            .from('urge_events')
            .select('id,created_at')
            .eq('user_id', pod.partnerId!)
            .isFilter('retracted_at', null)
            .isFilter('resolved_at', null)
            .gte('created_at', fresh)
            .order('created_at', ascending: false)
            .limit(1);
        final since = now.subtract(const Duration(days: 2)).toUtc().toIso8601String();
        final reps = await _c
            .from('encouragements')
            .select('id,from_user,template_key,urge_id,created_at')
            .gte('created_at', since)
            .order('created_at', ascending: false); // RLS: only replies I sent or received
        return PodActivity(
          partnerUrge: urges.isEmpty
              ? null
              : UrgeInfo(id: urges.first['id'] as String, createdAt: DateTime.parse(urges.first['created_at'] as String).toLocal()),
          replies: [
            for (final r in reps)
              ReplyInfo(
                id: r['id'] as String,
                fromMe: r['from_user'] == me,
                template: r['template_key'] as String,
                urgeId: r['urge_id'] as String?,
                createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
              ),
          ],
        );
      });

  @override
  Future<void> registerDevice(String platform, String token) =>
      _guard(() => _c.rpc('register_device', params: {'p_platform': platform, 'p_token': token}));

  @override
  Stream<void> changes(String podId) {
    late StreamController<void> ctl;
    RealtimeChannel? ch;
    ctl = StreamController<void>(
      onListen: () {
        ch = _c.channel('pod:$podId');
        for (final (table, col) in const [
          ('pods', 'id'),
          ('pod_members', 'pod_id'),
          ('check_ins', 'pod_id'),
          ('habits', 'pod_id'),
          ('habit_logs', 'pod_id'),
          ('urge_events', 'pod_id'),
          ('encouragements', 'pod_id'),
        ]) {
          ch!.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: col, value: podId),
            callback: (_) => ctl.add(null),
          );
        }
        ch!.subscribe();
      },
      onCancel: () async {
        if (ch != null) await _c.removeChannel(ch!);
      },
    );
    return ctl.stream;
  }

  @override
  Future<void> send(SyncOp op) => _guard(() async {
        switch (op) {
          case CheckInOp():
            await _c.rpc('upsert_check_in', params: {
              'p_pod': op.podId,
              'p_day': dayKey(op.day),
              'p_status': op.state.name,
              'p_note': op.note,
            });
          case HabitOp():
            await _c.rpc('upsert_habit', params: {
              'p_id': op.id,
              'p_pod': op.podId,
              'p_title': op.title,
              'p_created': dayKey(op.createdDay),
              'p_archived': op.archivedDay == null ? null : dayKey(op.archivedDay!),
            });
          case UrgeOp():
            await _c.from('urge_events').upsert(
              {'id': op.id, 'pod_id': op.podId, 'user_id': _c.auth.currentUser!.id},
              onConflict: 'id',
              ignoreDuplicates: true,
            );
          case UrgeUpdateOp():
            await _c.from('urge_events').update(
              op.retract
                  ? {'retracted_at': DateTime.now().toUtc().toIso8601String()}
                  : {'resolved_at': DateTime.now().toUtc().toIso8601String(), 'outcome': op.outcome},
            ).eq('id', op.id);
          case ReplyOp():
            await _c.from('encouragements').upsert(
              {
                'id': op.id,
                'pod_id': op.podId,
                'from_user': _c.auth.currentUser!.id,
                'to_user': op.toUser,
                'kind': op.kind,
                'template_key': op.template,
                'urge_id': op.urgeId,
              },
              onConflict: 'id',
              ignoreDuplicates: true,
            );
          case TickOp() when op.on:
            await _c.from('habit_logs').upsert(
              {'habit_id': op.habitId, 'user_id': _c.auth.currentUser!.id, 'pod_id': op.podId, 'local_date': dayKey(op.day)},
              onConflict: 'habit_id,local_date',
              ignoreDuplicates: true,
            );
          case TickOp():
            await _c.from('habit_logs').delete().eq('habit_id', op.habitId).eq('local_date', dayKey(op.day));
        }
      });
}
