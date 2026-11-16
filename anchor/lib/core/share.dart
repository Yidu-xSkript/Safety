import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a file to the system share sheet (save to Files, email it to yourself, ...). Overridden in tests.
final shareFileProvider = Provider<Future<void> Function(String name, String content)>(
  (_) => (name, content) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile.fromData(utf8.encode(content), mimeType: 'application/json')], fileNameOverrides: [name]),
    );
  },
);
