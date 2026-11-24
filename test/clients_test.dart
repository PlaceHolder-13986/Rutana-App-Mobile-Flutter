import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutana_app_movil/home/presentation/home_screen.dart';
import 'package:rutana_app_movil/routes/data/client_location_repository.dart';
import 'package:rutana_app_movil/routes/data/trip_repository.dart';
import 'package:rutana_app_movil/routes/domain/trip.dart';
import 'package:rutana_app_movil/routes/presentation/route_planning_screen.dart';
import 'package:rutana_app_movil/shared/theme/app_theme.dart';

import 'support/fleet_fixtures.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

Future<void> fill(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), value);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'RUC por empresa, permisos de escritura y coordenadas válidas',
    () async {
      final repo = ClientLocationRepository();
      final admin = testUser('clients-unit');
      final c = await repo.saveClient(
        admin,
        legalName: '  Cliente SAC ',
        ruc: '12345678901',
      );
      expect(c.legalName, 'Cliente SAC');
      expect(c.active, isTrue);
      await expectLater(
        repo.saveClient(admin, legalName: 'Otro', ruc: c.ruc),
        throwsStateError,
      );
      final other = testUser('clients-other');
      await repo.saveClient(other, legalName: 'Otro', ruc: c.ruc);
      expect(repo.clients(other).any((value) => value.id == c.id), isFalse);
      final driver = testUser(admin.ruc, role: 'Driver');
      expect(repo.client(driver, c.id).ruc, c.ruc);
      await expectLater(repo.setActive(driver, c.id, false), throwsStateError);
      await expectLater(
        repo.saveSite(
          admin,
          c.id,
          name: 'Sede',
          address: 'Calle',
          latitude: -12,
        ),
        throwsStateError,
      );
      await expectLater(
        repo.saveSite(
          admin,
          c.id,
          name: 'Sede',
          address: 'Calle',
          latitude: -91,
          longitude: 0,
        ),
        throwsStateError,
      );
    },
  );

  test('La edición conserva la copia del viaje y desactivar bloquea una publicación nueva', () async {
    final repo = ClientLocationRepository.instance;
    final routes = TripRepository();
    final admin = testUser('clients-route-snapshot');
    final c = await repo.saveClient(
      admin,
      legalName: 'Cliente',
      ruc: '12345678901',
    );
    final site = await repo.saveSite(
      admin,
      c.id,
      name: 'Sede A',
      address: 'Dirección original',
      contact: 'Ana',
      phone: '999000111',
      latitude: -12,
      longitude: -77,
    );
    final t = routes.create(admin)
      ..driver = 'driver@demo.pe'
      ..originLocation = site
      ..stops = [
        Stop.fromLocation(site, [Cargo('Cajas', 2)]),
      ];
    final edited = await repo.saveSite(
      admin,
      c.id,
      id: site.id,
      name: 'Sede A',
      address: 'Otra dirección',
      contact: 'Luis',
      active: false,
    );
    expect(edited.id, site.id);
    final snapshot = t.copy();
    expect(snapshot.originLocation!.address, 'Dirección original');
    expect(snapshot.stops.single.location!.clientId, c.id);
    expect(snapshot.stops.single.location!.longitude, -77);
    expect(snapshot.stops.single.contact, 'Ana · 999000111');
    expect(() => routes.publishFromPlanning(admin, snapshot), throwsStateError);
    await repo.saveSite(
      admin,
      c.id,
      id: site.id,
      name: site.siteName,
      address: edited.address,
    );
    routes.publishFromPlanning(admin, snapshot);
    await repo.setActive(admin, c.id, false);
    expect(snapshot.status, TripStatus.published);
    expect(snapshot.stops.single.address, 'Dirección original');
    expect(repo.inactiveReason(admin, site), contains('Cliente inactivo'));
  });

  testWidgets(
    'Home y menú comparten el listado. Registro, edición, duplicado y filtro',
    (tester) async {
      final admin = testUser('clients-home');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    settings: RouteSettings(arguments: admin),
                    builder: (_) => const HomeScreen(),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, find.text('Abrir'));
      await tap(tester, find.text('Clients'));
      await tap(tester, find.text('Nuevo cliente'));
      await fill(tester, 'Razón social', 'Cliente Pruebas SAC');
      await fill(tester, 'RUC', '12345678901');
      await tap(tester, find.text('Guardar'));
      await tap(tester, find.text('Editar cliente').last);
      await fill(tester, 'Nombre comercial', 'Nombre buscable');
      await tap(tester, find.text('Guardar'));
      await tap(tester, find.text('Sedes'));
      for (final name in ['Sede Uno', 'Sede Dos']) {
        await tap(tester, find.text('Nueva sede'));
        await fill(tester, 'Nombre de la sede', name);
        await fill(tester, 'Dirección', 'Dirección $name');
        await tap(tester, find.text('Guardar'));
        expect(find.text(name), findsOneWidget);
      }
      await tap(tester, find.text('Información'));
      await tap(tester, find.text('Desactivar cliente'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Nuevo cliente'));
      await fill(tester, 'Razón social', 'Duplicado');
      await fill(tester, 'RUC', '12345678901');
      await tap(tester, find.text('Guardar'));
      expect(
        find.text('Este RUC ya está registrado en tu empresa.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.byIcon(Icons.menu));
      await tap(tester, find.text('Home'));
      await tap(tester, find.byIcon(Icons.menu));
      await tap(tester, find.text('Clients').last);
      await fill(
        tester,
        'Buscar por razón social, nombre comercial o RUC',
        'buscable',
      );
      expect(find.text('Cliente Pruebas SAC'), findsOneWidget);
      await tap(tester, find.text('Todos'));
      await tap(tester, find.text('Activos').last);
      expect(
        find.textContaining('No hay clientes que coincidan'),
        findsOneWidget,
      );
      await tap(tester, find.text('Activos'));
      await tap(tester, find.text('Inactivos').last);
      expect(find.text('Cliente Pruebas SAC'), findsOneWidget);
      expect(find.textContaining('2 sedes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Routes conserva el borrador y refresca sedes al regresar de Clients',
    (tester) async {
      final admin = testUser('clients-route-widget');
      final catalog = ClientLocationRepository.instance;
      final client = await catalog.saveClient(
        admin,
        legalName: 'Cliente sin sedes',
        ruc: '12345678902',
      );
      final off = await catalog.saveClient(
        admin,
        legalName: 'Cliente oculto',
        ruc: '12345678903',
      );
      await catalog.setActive(admin, off.id, false);
      await catalog.saveSite(
        admin,
        client.id,
        name: 'Sede oculta',
        address: 'Av. Oculta',
        active: false,
      );
      final repo = TripRepository.instance;
      final trip = (await repo.list(admin)).single;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RoutePlanningScreen(user: admin, trip: trip),
        ),
      );
      await tester.pumpAndSettle();
      await fill(tester, 'Route name', 'Borrador preservado');
      await tap(tester, find.text('Cliente activo'));
      expect(find.text('Cliente oculto'), findsNothing);
      await tap(tester, find.text('Cliente sin sedes').last);
      expect(
        find.textContaining('Este cliente no tiene sedes activas'),
        findsOneWidget,
      );
      await tap(tester, find.text('Administrar clientes y sedes'));
      await tap(tester, find.text('Cliente sin sedes'));
      await tap(tester, find.text('Sedes'));
      await tap(tester, find.text('Nueva sede'));
      await fill(tester, 'Nombre de la sede', 'Sede visible');
      await fill(tester, 'Dirección', 'Av. Nueva');
      await fill(tester, 'Contacto de la sede', 'Contacto nuevo');
      await fill(tester, 'Latitud', '-12');
      await fill(tester, 'Longitud', '-77');
      await tap(tester, find.text('Guardar'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Sede activa'));
      expect(find.text('Sede oculta'), findsNothing);
      await tap(tester, find.text('Sede visible').last);
      await tap(tester, find.text('Usar como origen'));
      await tap(tester, find.text('Añadir parada'));
      await tap(tester, find.text('Save draft'));
      final saved = (await repo.list(admin)).single;
      expect(saved.name, 'Borrador preservado');
      expect(saved.stops.first.location, isNull);
      expect(saved.origin, 'Av. Nueva');
      expect(saved.originLocation!.clientId, client.id);
      expect(saved.stops.last.contact, 'Contacto nuevo');
      expect(saved.stops.last.location!.latitude, -12);
      expect(tester.takeException(), isNull);
    },
  );
}
