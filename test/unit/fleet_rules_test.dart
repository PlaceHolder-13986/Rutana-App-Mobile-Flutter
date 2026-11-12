import 'package:flutter_test/flutter_test.dart';
import 'package:rutana_app_movil/fleet/data/fleet_repository.dart';

import '../support/fleet_fixtures.dart';

void main() {
  late FleetRepository repo;
  final admin = testUser('unit-fleet');
  setUp(() => repo = FleetRepository());

  test('HU-V: normaliza placa y rechaza duplicado sin agregar registros', () {
    saveTestVehicle(repo, admin, plate: ' tst-123 ');
    final count = repo.vehicles(admin).length;
    expect(
      () => saveTestVehicle(repo, admin, plate: 'TST 123'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'mensaje',
          contains('placa'),
        ),
      ),
    );
    expect(repo.vehicles(admin).length, count);
  });

  test('HU-V: misma placa permitida en otra empresa y listas aisladas', () {
    saveTestVehicle(repo, admin);
    final other = testUser('other-unit-company');
    expect(repo.vehicles(other).where((v) => v.plate == 'TST123'), isEmpty);
    saveTestVehicle(repo, other);
    expect(repo.vehicles(admin).last.company, admin.ruc);
    expect(repo.vehicles(other).last.company, other.ruc);
  });

  for (final capacity in [0.0, -1.0, double.nan, double.infinity]) {
    test('HU-V: rechaza capacidad inválida $capacity', () {
      expect(
        () => saveTestVehicle(repo, admin, capacity: capacity),
        throwsStateError,
      );
      expect(repo.vehicles(admin).length, 1);
    });
  }

  test('HU-V: editar conserva identidad y evita duplicar el registro', () {
    final v = saveTestVehicle(repo, admin);
    final updated = saveTestVehicle(repo, admin, id: v.id, capacity: 4500);
    expect(updated.id, v.id);
    expect(
      repo.vehicles(admin).where((e) => e.id == v.id).single.capacity,
      4500,
    );
  });

  test('HU-E: editar equipo no modifica la composición anterior', () {
    final old = repo.saveCrew(
      admin,
      name: 'Lima',
      driver: 'd1',
      helpers: ['h1'],
      active: true,
      drivers: {'d1', 'd2'},
      helperOptions: {'h1'},
    );
    final current = repo.saveCrew(
      admin,
      id: old.id,
      name: 'Lima',
      driver: 'd2',
      helpers: [],
      active: true,
      drivers: {'d1', 'd2'},
      helperOptions: {'h1'},
    );
    expect(old.driver, 'd1');
    expect(old.helpers, ['h1']);
    expect(current.driver, 'd2');
    expect(repo.crews(admin).single.helpers, isEmpty);
  });

  test('HU-E: exige conductor válido y rechaza ayudantes repetidos', () {
    for (final driver in ['', 'unknown', 'd1']) {
      expect(
        () => repo.saveCrew(
          admin,
          name: 'Lima',
          driver: driver,
          helpers: ['h1', 'h1'],
          active: true,
          drivers: {'d1'},
          helperOptions: {'h1'},
        ),
        throwsStateError,
      );
    }
    expect(repo.crews(admin), isEmpty);
  });

  test('HU-V/E: conductor consulta pero no puede escribir', () {
    final driver = testUser(admin.ruc, role: 'Driver');
    expect(repo.vehicles(driver), isNotEmpty);
    expect(repo.crews(driver), isEmpty);
    expect(() => saveTestVehicle(repo, driver), throwsStateError);
    expect(
      () => repo.saveCrew(
        driver,
        name: 'Lima',
        driver: driver.email,
        helpers: [],
        active: true,
        drivers: {driver.email},
        helperOptions: {},
      ),
      throwsStateError,
    );
  });

  test('HU-V/E: rechaza empresa vacía y rol desconocido', () {
    expect(() => repo.vehicles(testUser('')), throwsStateError);
    expect(
      () => repo.crews(testUser('company', role: 'Unknown')),
      throwsStateError,
    );
  });
}
