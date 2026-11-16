// Nothing the app prints can name a person or a habit: there is no logging at all in lib/ (docs/SECURITY.md).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/ never prints or logs', () {
    final bad = RegExp(r'(^|[^\w.])(print|debugPrint|debugPrintStack)\s*\(|developer\.log\s*\(|stdout\.write|stderr\.write');
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (f.path.contains('l10n')) continue; // generated
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (bad.hasMatch(code)) hits.add('${f.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(hits, isEmpty, reason: 'remove these; a log line can name a person or a habit');
  });

  test('the Edge Functions log nothing either', () {
    final hits = <String>[];
    for (final f in Directory('supabase/functions').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.ts') && !f.path.endsWith('.test.ts'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'console\.(log|error|warn|info|debug)').hasMatch(lines[i].split('//').first)) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty);
  });
}
