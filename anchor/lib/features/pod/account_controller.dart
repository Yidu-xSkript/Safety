import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/pod_backend.dart';
import 'pod_controller.dart';

class AccountState {
  const AccountState([this.email]);

  /// Null while the account is anonymous (the default until "Secure your pod").
  final String? email;
  bool get secured => email != null;
}

/// Securing the anonymous account with an emailed code, and signing back in after a reinstall.
/// No password anywhere: a code each time, nothing stored.
class AccountController extends AsyncNotifier<AccountState> {
  PodBackend get _backend => ref.read(backendProvider);

  @override
  Future<AccountState> build() async {
    try {
      return AccountState(await _backend.accountEmail());
    } on PodError {
      return const AccountState(); // unconfigured or offline: treated as not secured; refreshed when asked
    }
  }

  Future<void> requestLink(String email) => _backend.requestEmailLink(email.trim());

  Future<void> confirmLink(String email, String code) async {
    await _backend.confirmEmailLink(email.trim(), code.trim());
    state = AsyncData(AccountState(email.trim()));
  }

  Future<void> requestSignIn(String email) => _backend.requestSignIn(email.trim());

  /// Signs in and rebuilds this phone from the server. False when that account has no pod.
  Future<bool> confirmSignIn(String email, String code) async {
    await _backend.confirmSignIn(email.trim(), code.trim());
    final found = await ref.read(podProvider.notifier).restoreFromServer();
    state = AsyncData(AccountState(email.trim()));
    return found;
  }
}

final accountProvider = AsyncNotifierProvider<AccountController, AccountState>(AccountController.new);
