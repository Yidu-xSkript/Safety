// Platform-native controls behind one small API. Screens call these, never branch on platform themselves.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive_page.dart';

enum ButtonKind { filled, outlined, text }

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({super.key, required this.label, required this.onPressed, this.kind = ButtonKind.filled, this.expand = false});

  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget button;
    if (isIOS(context)) {
      final child = Text(label);
      button = switch (kind) {
        ButtonKind.filled => CupertinoButton.filled(onPressed: onPressed, child: child),
        ButtonKind.outlined => CupertinoButton.tinted(onPressed: onPressed, child: child),
        ButtonKind.text => CupertinoButton(onPressed: onPressed, child: child),
      };
    } else {
      const tall = Size(48, 56);
      button = switch (kind) {
        ButtonKind.filled => FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(minimumSize: tall), child: Text(label)),
        ButtonKind.outlined => OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(minimumSize: tall), child: Text(label)),
        ButtonKind.text => TextButton(onPressed: onPressed, style: TextButton.styleFrom(minimumSize: const Size(48, 48)), child: Text(label)),
      };
    }
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class AdaptiveTextField extends StatelessWidget {
  const AdaptiveTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.capitalization = TextCapitalization.sentences,
    this.inputFormatters,
    this.style,
    this.textAlign = TextAlign.start,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    if (isIOS(context)) {
      return CupertinoTextField(
        controller: controller,
        placeholder: hint,
        maxLength: maxLength,
        maxLines: maxLines,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
        textCapitalization: capitalization,
        padding: const EdgeInsets.all(14),
        inputFormatters: inputFormatters,
        keyboardType: keyboardType,
        textAlign: textAlign,
        style: style ?? TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17),
      );
    }
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      textCapitalization: capitalization,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      textAlign: textAlign,
      style: style,
      decoration: InputDecoration(hintText: hint, counterText: ''),
    );
  }
}

/// Top-level screen without a nav bar (onboarding): safe area, platform background.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isIOS(context)) {
      return CupertinoPageScaffold(child: Material(type: MaterialType.transparency, child: SafeArea(child: child)));
    }
    return Scaffold(body: SafeArea(child: child));
  }
}

/// Modal sheet: Cupertino popup on iOS, Material bottom sheet elsewhere. Rises above the keyboard.
Future<T?> adaptiveSheet<T>(BuildContext context, WidgetBuilder builder) {
  Widget body(BuildContext ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(top: false, child: builder(ctx)),
      );
  if (isIOS(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoPopupSurface(child: Material(type: MaterialType.transparency, child: body(ctx))),
    );
  }
  return showModalBottomSheet<T>(context: context, isScrollControlled: true, useSafeArea: true, builder: body);
}
