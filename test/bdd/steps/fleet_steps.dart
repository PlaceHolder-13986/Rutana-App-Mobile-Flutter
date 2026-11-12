import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutana_app_movil/fleet/data/fleet_repository.dart';
import 'package:rutana_app_movil/home/presentation/home_screen.dart';
import 'package:rutana_app_movil/iam/domain/user.dart';
import 'package:rutana_app_movil/routes/data/trip_repository.dart';
import 'package:rutana_app_movil/routes/domain/trip.dart';

import '../../support/fleet_fixtures.dart';

class FleetSteps {
  final WidgetTester tester;
  final User admin;
  final fleet = FleetRepository.instance;
  final routes = TripRepository.instance;
  Vehicle? vehicle;
  Trip? original, candidate;
  StateError? failure;
  int? count;

  FleetSteps(this.tester, String scenario) : admin = testUser('bdd-$scenario');

  Future<void> tap(Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder input(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );

  Future<void> fill(String label, String value) async {
    final target = input(label);
    await tester.ensureVisible(target);
    await tester.enterText(target, value);
    await tester.pumpAndSettle();
  }

  Future<void> vehicleForm(String plate) async {
    await tap(find.text('Nuevo vehículo'));
    await fill('Placa', plate);
    await fill('Marca', 'Volvo');
    await fill('Modelo', 'FH');
    await fill('Capacidad de carga (kg)', '3000');
    await tap(find.text('Guardar'));
  }

  Trip trip(String plate, String driver) => routes.create(admin)
    ..name = 'Entrega Lima'
    ..origin = 'Ate'
    ..departure = DateTime(2030, 1, 2, 8)
    ..plate = plate
    ..driver = driver
    ..stops = [
      Stop('Callao', 'Av. Argentina', 'Recepción', [Cargo('Cajas', 5)]),
    ];

  void attempt(VoidCallback action) {
    failure = null;
    try {
      action();
    } on StateError catch (e) {
      failure = e;
    }
  }

  Future<void> execute(String step) async {
    switch (step) {
      case 'que existe un vehículo habilitado':
        vehicle = saveTestVehicle(fleet, admin);
        count = fleet.vehicles(admin).length;
        break;
      case 'registro la misma placa con espacios y minúsculas':
        attempt(() => saveTestVehicle(fleet, admin, plate: 'tst 123'));
        break;
      case 'se rechaza el duplicado sin cambiar la flota':
        expect(failure?.message, contains('placa'));
        expect(fleet.vehicles(admin).length, count);
        break;
      case 'que existe un viaje publicado':
        vehicle = saveTestVehicle(fleet, admin);
        original = trip(vehicle!.plate, 'driver@demo.pe');
        routes.publish(admin, original!);
        break;
      case 'publico otro viaje con el mismo vehículo':
        candidate = trip(vehicle!.plate, 'other@demo.pe');
        attempt(() => routes.publish(admin, candidate!));
        break;
      case 'el error identifica el vehículo y el viaje original':
        expect(
          failure?.message,
          allOf(
            contains('Vehículo'),
            contains(vehicle!.plate),
            contains(original!.id),
          ),
        );
        expect(candidate!.status, TripStatus.draft);
        break;
      case 'publico otro viaje con el mismo conductor y otro vehículo':
        final other = saveTestVehicle(fleet, admin, plate: 'OTR456');
        candidate = trip(other.plate, original!.driver);
        attempt(() => routes.publish(admin, candidate!));
        break;
      case 'el error identifica el conductor y el viaje original':
        expect(
          failure?.message,
          allOf(
            contains('Conductor'),
            contains(original!.driver),
            contains(original!.id),
          ),
        );
        expect(candidate!.status, TripStatus.draft);
        break;
      case 'deshabilito su vehículo':
        attempt(
          () => saveTestVehicle(
            fleet,
            admin,
            id: vehicle!.id,
            status: VehicleStatus.inactive,
          ),
        );
        break;
      case 'el error identifica el viaje que debe atender el coordinador':
        expect(failure?.message, contains(original!.id));
        expect(fleet.vehicles(admin).last.status, VehicleStatus.enabled);
        break;
      case 'que existe un vehículo en mantenimiento':
        vehicle = saveTestVehicle(
          fleet,
          admin,
          status: VehicleStatus.maintenance,
        );
        break;
      case 'publico un viaje con ese vehículo':
        candidate = trip(vehicle!.plate, 'driver@demo.pe');
        attempt(() => routes.publish(admin, candidate!));
        break;
      case 'la publicación se rechaza y el viaje sigue en borrador':
        expect(failure, isNotNull);
        expect(candidate!.status, TripStatus.draft);
        expect(routes.assignments(admin), isEmpty);
        break;
      case 'que abro Vehículos y equipos como administrador':
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    settings: RouteSettings(arguments: admin),
                    builder: (_) => const HomeScreen(),
                  ),
                ),
                child: const Text('Abrir aplicación'),
              ),
            ),
          ),
        );
        await tap(find.text('Abrir aplicación'));
        await tap(find.byIcon(Icons.menu));
        await tap(find.text('Vehicles and teams').last);
        break;
      case 'registro un vehículo desde el formulario':
        await vehicleForm('UIV123');
        break;
      case 'el vehículo aparece en el listado':
        expect(find.text('UIV123'), findsOneWidget);
        expect(fleet.vehicles(admin).last.capacity, 3000);
        break;
      case 'edito su capacidad desde el detalle':
        await tap(find.text('UIV123'));
        await tap(find.text('Editar'));
        await fill('Capacidad de carga (kg)', '4500');
        await tap(find.text('Guardar'));
        break;
      case 'la capacidad actualizada aparece en el listado':
        expect(find.textContaining('4500.0 kg'), findsOneWidget);
        expect(fleet.vehicles(admin).last.capacity, 4500);
        break;
      case 'registro una placa equivalente desde el formulario':
        count = fleet.vehicles(admin).length;
        await vehicleForm('uiv 123');
        break;
      case 'el formulario muestra el rechazo por placa duplicada':
        expect(
          find.textContaining('La placa ya está registrada'),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(fleet.vehicles(admin).length, count);
        break;
      case 'creo un equipo con conductor y ayudante':
        await tap(find.text('Equipos'));
        await tap(find.text('Nuevo equipo'));
        await fill('Nombre del equipo', 'Equipo Lima');
        await tap(find.byType(DropdownButtonFormField<String>).last);
        await tap(find.text('driver@demo.pe').last);
        await tap(find.text('helper@demo.pe'));
        await tap(find.text('Guardar'));
        break;
      case 'el equipo aparece con su conductor y ayudante':
        expect(find.text('Equipo Lima'), findsOneWidget);
        expect(find.textContaining('driver@demo.pe'), findsOneWidget);
        expect(find.textContaining('helper@demo.pe'), findsOneWidget);
        expect(fleet.crews(admin).single.driver, 'driver@demo.pe');
        expect(fleet.crews(admin).single.helpers, ['helper@demo.pe']);
        break;
      default:
        throw StateError('Paso sin implementación: $step');
    }
  }
}
