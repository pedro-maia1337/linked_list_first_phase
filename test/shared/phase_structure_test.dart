import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linked_list_first_phase/phases/phase_registry.dart';
import 'package:linked_list_first_phase/shared/phases/phase_game.dart';

/// Guards the shared/phase split (see `docs/ESTRUTURA.md`): shared code
/// never depends on a phase, and every registered phase follows the folder
/// and asset convention its `PhaseDefinition` declares.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nothing under lib/shared imports a phase', () {
    final offenders = <String>[];
    for (final file in Directory('lib/shared').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final imports = RegExp(r"^(?:import|export) '([^']+)'", multiLine: true)
          .allMatches(file.readAsStringSync())
          .map((m) => m.group(1)!);
      for (final target in imports) {
        if (target.contains('phases/') && !target.contains('shared/phases/') &&
            !target.startsWith('phase_')) {
          offenders.add('${file.path} -> $target');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('every registered phase follows the folder convention', () {
    final ids = phaseRegistry.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
    expect(ids, contains('linked_list'));

    for (final phase in phaseRegistry) {
      expect(Directory('lib/phases/${phase.id}').existsSync(), isTrue,
          reason: phase.id);
      expect(Directory('assets/phases/${phase.id}').existsSync(), isTrue,
          reason: phase.id);
      expect(phase.assetRoot, 'phases/${phase.id}/');
      expect(phase.levelConfigPath, startsWith('assets/${phase.assetRoot}'));
      expect(File(phase.levelConfigPath).existsSync(), isTrue,
          reason: phase.levelConfigPath);
      expect(phaseById(phase.id), same(phase));
    }
  });

  test('each phase builds a PhaseGame that knows its own definition', () {
    for (final phase in phaseRegistry) {
      final PhaseGame game = phase.createGame();
      expect(game.definition, same(phase));
    }
  });

  test('every asset folder the phases and shared code use is in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final dir in [
      'assets/shared/',
      for (final phase in phaseRegistry) 'assets/${phase.assetRoot}',
    ]) {
      expect(pubspec, contains('- $dir'), reason: dir);
    }
  });
}
