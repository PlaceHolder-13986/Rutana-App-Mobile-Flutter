import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rutana_app_movil/fleet/data/fleet_repository.dart';
import 'package:rutana_app_movil/home/presentation/home_screen.dart';
import 'package:rutana_app_movil/iam/domain/user.dart';
import 'package:rutana_app_movil/routes/data/trip_repository.dart';
import 'package:rutana_app_movil/routes/domain/trip.dart';

const admin = User(
  fullName: 'Admin',
  email: 'admin@fleet.pe',
  phone: '',
  company: 'Fleet',
  ruc: 'fleet-tests',
  password: '',
  role: 'Administrator',
);

void main() {
  test('Company scope, normalized duplicates, edit and crew validation', () {
    final r = FleetRepository();
    final v = r.saveVehicle(
      admin,
      plate: ' xyz-123 ',
      type: 'Camión',
      brand: 'A',
      model: 'B',
      capacity: 3000,
      status: VehicleStatus.enabled,
    );
    expect(v.plate, 'XYZ123');
    expect(
      () => r.saveVehicle(
        admin,
        plate: 'XYZ 123',
        type: 'Camión',
        brand: 'A',
        model: 'B',
        capacity: 3000,
        status: VehicleStatus.enabled,
      ),
      throwsStateError,
    );
    r.saveVehicle(
      admin,
      id: v.id,
      plate: v.plate,
      type: v.type,
      brand: 'Nueva',
      model: v.model,
      capacity: 4000,
      status: VehicleStatus.maintenance,
    );
    expect(r.vehicles(admin).last.capacity, 4000);
    expect(
      () => r.saveVehicle(
        admin,
        plate: 'OTHER',
        type: 'Camión',
        brand: 'A',
        model: 'B',
        capacity: 0,
        status: VehicleStatus.enabled,
      ),
      throwsStateError,
    );
    final crew = r.saveCrew(
      admin,
      name: 'Lima',
      driver: 'driver',
      helpers: ['helper'],
      active: true,
      drivers: {'driver'},
      helperOptions: {'helper'},
    );
    expect(crew.helpers, ['helper']);
    expect(
      () => r.saveCrew(
        admin,
        name: 'Lima',
        driver: 'driver',
        helpers: ['driver'],
        active: true,
        drivers: {'driver'},
        helperOptions: {'driver'},
      ),
      throwsStateError,
    );
  });

  test(
    'Routes accepts registered enabled fleet and locks operational changes',
    () async {
      final fleet = FleetRepository.instance;
      final routes = TripRepository.instance;
      final v = fleet.saveVehicle(
        admin,
        plate: 'FLE123',
        type: 'Camión',
        brand: 'A',
        model: 'B',
        capacity: 3000,
        status: VehicleStatus.enabled,
      );
      final t = (await routes.list(admin)).single.copy()..plate = v.plate;
      routes.publish(admin, t);
      expect(
        () => fleet.saveVehicle(
          admin,
          id: v.id,
          plate: v.plate,
          type: v.type,
          brand: v.brand,
          model: v.model,
          capacity: v.capacity,
          status: VehicleStatus.inactive,
        ),
        throwsStateError,
      );
      final second = routes.create(admin)
        ..name = t.name
        ..origin = t.origin
        ..departure = t.departure
        ..plate = t.plate
        ..driver = 'other'
        ..stops = t.stops;
      expect(() => routes.publish(admin, second), throwsStateError);
      expect(t.status, TripStatus.published);
    },
  );

  testWidgets('Vehicles and teams opens from drawer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                settings: const RouteSettings(arguments: admin),
                builder: (_) => const HomeScreen(),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vehicles and teams').last);
    await tester.pumpAndSettle();
    expect(find.text('Nuevo vehículo'), findsOneWidget);
    await tester.tap(find.text('Equipos'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo equipo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
