// ignore_for_file: sort_child_properties_last
// "Enter your email, enter the code": used to secure the pod and to sign back in after a reinstall. No password.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive/adaptive_widgets.dart';
import '../../core/adaptive/step_layout.dart';
import '../../l10n/app_localizations.dart';
import 'account_controller.dart';
import 'pairing_screens.dart' show podErrorText;

class EmailCodeScreen extends StatefulWidget {
  const EmailCodeScreen({
    super.key,
    required this.title,
    required this.body,
    required this.request,
    required this.verify,
    this.doneText,
    this.failText,
  });

  final String title;
  final String body;

  /// Sends the code. Throws [PodError] to be shown.
  final Future<void> Function(String email) request;

  /// Checks the code. True = finished; false = it worked but there is nothing to restore (shows [failText]).
  final Future<bool> Function(String email, String code) verify;

  /// When set, a confirmation step follows; otherwise the screen simply closes on success.
  final String? doneText;
  final String? failText;

  @override
  State<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends State<EmailCodeScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  int _step = 0; // 0 email, 1 code, 2 done
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } catch (e) {
      if (mounted) setState(() => _error = podErrorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _send() => _run(() async {
        await widget.request(_email.text.trim());
        if (mounted) setState(() => _step = 1);
      });

  Future<void> _verify() => _run(() async {
        final nav = Navigator.of(context);
        final ok = await widget.verify(_email.text.trim(), _code.text.trim());
        if (!mounted) return;
        if (!ok) return setState(() => _error = widget.failText);
        if (widget.doneText != null) {
          setState(() => _step = 2);
        } else {
          nav.popUntil((r) => r.isFirst); // the root re-routes from the restored state
        }
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final error = _error == null ? <Widget>[] : [const SizedBox(height: 16), Text(_error!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error))];

    if (_step == 2) {
      return StepLayout(
        children: [const SizedBox(height: 24), Text(widget.doneText!, style: t.headlineMedium)],
        actions: [AdaptiveButton(label: l.done, expand: true, onPressed: () => Navigator.of(context).pop())],
      );
    }
    if (_step == 1) {
      return StepLayout(
        children: [
          const SizedBox(height: 8),
          Text(l.codeTitle, style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(l.codeBody(_email.text.trim()), style: t.bodyLarge),
          const SizedBox(height: 24),
          AdaptiveTextField(
            controller: _code,
            hint: l.codeHint,
            maxLength: 6,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: t.headlineMedium?.copyWith(letterSpacing: 6, color: Theme.of(context).colorScheme.onSurface),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _error = null),
          ),
          ...error,
        ],
        actions: [AdaptiveButton(label: l.verify, expand: true, onPressed: _code.text.trim().length == 6 && !_busy ? _verify : null)],
      );
    }
    return StepLayout(
      children: [
        const SizedBox(height: 8),
        Text(widget.title, style: t.headlineMedium),
        const SizedBox(height: 8),
        Text(widget.body, style: t.bodyLarge),
        const SizedBox(height: 24),
        AdaptiveTextField(
          controller: _email,
          hint: l.emailHint,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          capitalization: TextCapitalization.none,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _emailOk && !_busy ? _send() : null,
        ),
        ...error,
      ],
      actions: [AdaptiveButton(label: l.sendCode, expand: true, onPressed: _emailOk && !_busy ? _send : null)],
    );
  }
}

/// Pod settings → "Secure your pod".
class SecureScreen extends ConsumerWidget {
  const SecureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final account = ref.read(accountProvider.notifier);
    return EmailCodeScreen(
      title: l.secureTitle,
      body: l.secureBody,
      request: account.requestLink,
      verify: (email, code) async {
        await account.confirmLink(email, code);
        return true;
      },
      doneText: l.secureDone,
    );
  }
}

/// Welcome → "I already have an account": sign back in and rebuild this phone from the server.
class RestoreScreen extends ConsumerWidget {
  const RestoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final account = ref.read(accountProvider.notifier);
    return EmailCodeScreen(
      title: l.restoreTitle,
      body: l.restoreBody,
      request: account.requestSignIn,
      verify: account.confirmSignIn,
      failText: l.restoreNone,
    );
  }
}
