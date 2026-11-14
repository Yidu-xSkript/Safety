// Two phones, one in-memory server: each phone has its own storage and its own provider container, so tests
// drive the real controllers end to end. Shared by the pairing, urge and push tests.
import 'package:anchor/core/backend/pod_backend.dart';
import 'package:anchor/core/kv.dart';
import 'package:anchor/features/pod/pod_controller.dart';
import 'package:anchor/features/today/solo_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart' show testNow;
import 'fake_backend.dart';
import 'memory_kv.dart';

/// One phone: its own storage, its own app state, talking to the shared [server].
class Phone {
  Phone(this.server, this.id) : kv = MemoryKV() {
    backend = FakeBackend(server, id);
    boot();
  }

  final FakeServer server;
  final String id;
  final MemoryKV kv;
  late final FakeBackend backend;
  late ProviderContainer c;

  /// (Re)starts the app over the same storage, like closing and reopening it.
  void boot() {
    c = ProviderContainer(overrides: [
      kvProvider.overrideWith((_) async => kv),
      backendProvider.overrideWithValue(backend),
      clockProvider.overrideWithValue(server.now), // phones and server share one clock
    ]);
  }

  Future<void> ready() async {
    await c.read(soloProvider.future);
    await c.read(podProvider.future);
  }

  SoloController get solo => c.read(soloProvider.notifier);
  PodController get pod => c.read(podProvider.notifier);
  SoloState get s => c.read(soloProvider).requireValue;
  PodState get p => c.read(podProvider).requireValue;

  Future<void> onboard(String name, List<String> habits) async {
    await ready();
    await solo.completeOnboarding(name, habits);
  }

  void stop() => c.dispose();
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));
Future<void> realtime() => Future<void>.delayed(const Duration(milliseconds: 450)); // 300ms debounce + slack

Matcher podError(PodErrorKind k) => throwsA(isA<PodError>().having((e) => e.kind, 'kind', k));

/// Mika creates a pod, Teo joins with its code.
Future<(Phone, Phone, FakeServer)> pair() async {
  final server = FakeServer(start: testNow);
  final mika = Phone(server, 'mika'), teo = Phone(server, 'teo');
  await mika.onboard('Mika', ['Reading', 'Workout']);
  await teo.onboard('Teo', ['Prayer']);
  await mika.pod.createPod();
  await teo.pod.joinPod(mika.p.pod!.inviteCode!);
  await mika.pod.refresh();
  await settle();
  return (mika, teo, server);
}
