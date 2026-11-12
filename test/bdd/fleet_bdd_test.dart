import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'steps/fleet_steps.dart';

/// Ejecutor del subconjunto Gherkin usado por fleet.feature.
/// No admite Background, Examples, tablas ni Scenario Outline.
/// Toda línea o paso desconocido falla: no se omiten escenarios silenciosamente.
void main() {
  final lines = File('test/bdd/features/fleet.feature').readAsLinesSync();
  String? scenario;
  var steps = <String>[];
  void register() {
    if (scenario == null) return;
    final title = scenario;
    final scenarioSteps = List<String>.of(steps);
    if (scenarioSteps.isEmpty) {
      throw FormatException('Escenario sin pasos: $title');
    }
    testWidgets('BDD: $title', (tester) async {
      final world = FleetSteps(tester, title);
      for (final step in scenarioSteps) {
        await world.execute(step);
      }
      expect(tester.takeException(), isNull);
    });
  }

  var inFeatureDescription = false;
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith('@')) continue;
    if (line.startsWith('Característica:')) {
      inFeatureDescription = true;
    } else if (line.startsWith('Escenario:')) {
      register();
      scenario = line.substring('Escenario:'.length).trim();
      steps = [];
      inFeatureDescription = false;
    } else if (RegExp(r'^(Dado|Cuando|Entonces|Y|Pero) ').hasMatch(line)) {
      if (scenario == null) throw FormatException('Paso sin escenario: $line');
      steps.add(
        line.replaceFirst(RegExp(r'^(Dado|Cuando|Entonces|Y|Pero) '), ''),
      );
    } else if (!inFeatureDescription) {
      throw FormatException('Gherkin no soportado: $line');
    }
  }
  register();
  if (scenario == null) throw const FormatException('No hay escenarios');
}
