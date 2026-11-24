import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutana_app_movil/fleet/data/fleet_repository.dart';
import 'package:rutana_app_movil/home/presentation/home_screen.dart';
import 'package:rutana_app_movil/iam/data/company_members_repository.dart';
import 'package:rutana_app_movil/iam/domain/company_access.dart';
import 'package:rutana_app_movil/iam/domain/company_member.dart';
import 'package:rutana_app_movil/iam/domain/user.dart';
import 'package:rutana_app_movil/routes/data/trip_repository.dart';
import 'package:rutana_app_movil/routes/domain/trip.dart';
import 'package:rutana_app_movil/shared/theme/app_theme.dart';

import 'support/fleet_fixtures.dart';

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String label, String text) async {
  final target = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  await tester.ensureVisible(target);
  await tester.enterText(target, text);
  await tester.pumpAndSettle();
}

Matcher errorContaining(String text) => throwsA(
  isA<StateError>().having((error) => error.message, 'mensaje', contains(text)),
);

User testUserWithEmail(
  String company,
  String email, {
  String role = 'Coordinator',
}) => User(
  email: email,
  fullName: email,
  phone: '',
  company: company,
  ruc: company,
  password: '',
  role: role,
);

void main() {
  test(
    'Ámbito de empresa, invitación normalizada, cancelación y vencimiento',
    () async {
      var now = DateTime(2025, 1, 1);
      final first = testUser('iam-first');
      final second = testUser('iam-second');
      final existing = testUserWithEmail(first.ruc, 'existing@example.com');
      final repo = CompanyMembersRepository(
        (user) async => [if (user.ruc == first.ruc) existing],
        now: () => now,
      );
      await repo.refresh(first);
      await expectLater(
        repo.invite(first, existing.email, CompanyRole.helper, ''),
        errorContaining('pertenece'),
      );
      await repo.invite(
        first,
        '  NUEVA@example.com  ',
        CompanyRole.helper,
        'Nueva',
      );
      await expectLater(
        repo.invite(first, 'nueva@example.com', CompanyRole.driver, ''),
        errorContaining('pendiente'),
      );
      await repo.invite(second, 'nueva@example.com', CompanyRole.driver, '');
      final firstInvite = repo.invitations(first).first;
      await repo.resolveInvitation(first, firstInvite.id, accept: false);
      expect(repo.invitations(first).first.status, InvitationStatus.cancelled);
      await expectLater(
        repo.resolveInvitation(first, firstInvite.id, accept: true),
        errorContaining('pendiente'),
      );
      final secondInvite = repo.invitations(second).first;
      now = now.add(const Duration(days: 7));
      expect(repo.status(secondInvite), InvitationStatus.expired);
      await expectLater(
        repo.resolveInvitation(second, secondInvite.id, accept: true),
        errorContaining('pendiente'),
      );
      final driver = testUser('iam-forbidden', role: 'Driver');
      await expectLater(
        repo.invite(driver, 'otra@example.com', CompanyRole.driver, ''),
        errorContaining('administradores'),
      );
    },
  );

  test(
    'Protege el último administrador y aplica cambios a la sesión existente',
    () async {
      final actor = testUser('iam-admin');
      final accounts = <User>[];
      final repo = CompanyMembersRepository((_) async => accounts);
      await expectLater(
        repo.changeAccess(actor, actor.email, CompanyRole.coordinator, true),
        errorContaining('administrador activo'),
      );
      await expectLater(
        repo.changeAccess(actor, actor.email, CompanyRole.administrator, false),
        errorContaining('administrador activo'),
      );
      await repo.invite(
        actor,
        'second@example.com',
        CompanyRole.administrator,
        'Segunda',
      );
      await repo.resolveInvitation(
        actor,
        repo.invitations(actor).first.id,
        accept: true,
      );
      await expectLater(
        repo.changeAccess(actor, actor.email, CompanyRole.coordinator, true),
        errorContaining('cuenta local'),
      );
      final localAdmin = testUserWithEmail(
        actor.ruc,
        'local-admin@example.com',
        role: 'Administrator',
      );
      accounts.add(localAdmin);
      await repo.changeAccess(
        actor,
        actor.email,
        CompanyRole.coordinator,
        true,
      );
      expect(CompanyAccess.canManage(actor), isFalse);
      expect(TripRepository.instance.canPlan(actor), isTrue);
      expect(FleetRepository.instance.canEdit(actor), isFalse);
      await repo.changeAccess(
        localAdmin,
        actor.email,
        CompanyRole.coordinator,
        false,
      );
      expect(CompanyAccess.accessRemoved(actor), isTrue);
      await repo.changeAccess(
        localAdmin,
        actor.email,
        CompanyRole.coordinator,
        true,
      );
      expect(CompanyAccess.role(actor), CompanyRole.coordinator);
    },
  );

  test('Protege conductor y ayudante asignados y conserva la tripulación del viaje', () async {
    final actor = testUser('iam-assignments');
    final repo = CompanyMembersRepository.instance;
    await repo.refresh(actor);
    final fleet = FleetRepository.instance;
    final routes = TripRepository.instance;
    final team = fleet.saveCrew(
      actor,
      name: 'Turno Callao',
      driver: 'driver@demo.pe',
      helpers: ['helper@demo.pe'],
      active: true,
      drivers: {'driver@demo.pe'},
      helperOptions: {'helper@demo.pe'},
    );
    final trip = (await routes.list(actor)).single.copy()..assignedTeam = team;
    routes.publishFromPlanning(actor, trip);
    await expectLater(
      repo.changeAccess(actor, team.driver, CompanyRole.driver, false),
      errorContaining(trip.id),
    );
    await expectLater(
      repo.changeAccess(actor, team.helpers.single, CompanyRole.driver, true),
      errorContaining(trip.id),
    );
    routes.returnToDraft(actor, trip);
    await expectLater(
      repo.changeAccess(actor, team.helpers.single, CompanyRole.driver, true),
      errorContaining(team.name),
    );
    fleet.saveCrew(
      actor,
      id: team.id,
      name: team.name,
      driver: team.driver,
      helpers: [],
      active: true,
      drivers: {team.driver},
      helperOptions: {},
    );
    await repo.changeAccess(
      actor,
      team.helpers.single,
      CompanyRole.driver,
      true,
    );
    expect(
      repo.eligible(actor, CompanyRole.driver).map((m) => m.email),
      contains(team.helpers.single),
    );
    expect(trip.assignedTeam!.helpers, ['helper@demo.pe']);
    expect(
      () => routes.publishFromPlanning(actor, trip),
      errorContaining('rol correspondiente'),
    );
    await repo.changeAccess(
      actor,
      'coordinator@demo.pe',
      CompanyRole.coordinator,
      false,
    );
    expect(
      repo
          .members(actor)
          .firstWhere((m) => m.email == 'coordinator@demo.pe')
          .active,
      isFalse,
    );
    await repo.changeAccess(
      actor,
      'coordinator@demo.pe',
      CompanyRole.coordinator,
      true,
    );
    expect(
      repo
          .members(actor)
          .firstWhere((m) => m.email == 'coordinator@demo.pe')
          .active,
      isTrue,
    );
  });

  test(
    'Conserva el ayudante del viaje completado al retirar su acceso',
    () async {
      final actor = testUser('iam-completed');
      final repo = CompanyMembersRepository.instance;
      final fleet = FleetRepository.instance;
      final routes = TripRepository.instance;
      await repo.refresh(actor);
      final crew = fleet.saveCrew(
        actor,
        name: 'Turno Lima',
        driver: 'driver@demo.pe',
        helpers: ['helper@demo.pe'],
        active: true,
        drivers: {'driver@demo.pe'},
        helperOptions: {'helper@demo.pe'},
      );
      final trip = (await routes.list(actor)).single.copy()
        ..assignedTeam = crew;
      routes.publishFromPlanning(actor, trip);
      routes.confirmLoad(actor, trip);
      routes.dispatch(actor, trip);
      routes.start(actor, trip);
      for (final (index, stop) in trip.stops.indexed) {
        routes.deliver(
          actor,
          trip,
          index,
          DeliveryResult.completed,
          stop.cargo.map((c) => c.planned).toList(),
          '',
        );
      }
      routes.close(actor, trip, '');
      fleet.saveCrew(
        actor,
        id: crew.id,
        name: crew.name,
        driver: crew.driver,
        helpers: [],
        active: true,
        drivers: {crew.driver},
        helperOptions: {},
      );
      await repo.changeAccess(
        actor,
        'helper@demo.pe',
        CompanyRole.helper,
        false,
      );
      expect(trip.status, TripStatus.completed);
      expect(trip.assignedTeam!.helpers, ['helper@demo.pe']);
      expect(repo.eligible(actor, CompanyRole.helper), isEmpty);
    },
  );

  testWidgets(
    'Home, menú, filtros, invitaciones y alta de personal en el selector de flota',
    (tester) async {
      final actor = testUser('iam-ui');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: RouteSettings(arguments: actor),
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
      await tap(tester, find.text('User management'));
      expect(find.text('Usuarios'), findsOneWidget);
      await fill(tester, 'Buscar por nombre o correo', 'conductor');
      expect(find.text('Conductor demo'), findsOneWidget);
      await tap(tester, find.text('Todos').first);
      await tap(tester, find.text('Ayudante').last);
      expect(
        find.text('No hay usuarios que coincidan con los filtros.'),
        findsOneWidget,
      );
      await fill(tester, 'Buscar por nombre o correo', '');
      expect(find.text('Ayudante demo'), findsOneWidget);

      Future<void> invite(String address, String role, String name) async {
        await tap(tester, find.text('Invitar usuario'));
        await fill(tester, 'Correo electrónico', address);
        await tap(tester, find.text('Rol'));
        await tap(tester, find.text(role).last);
        await fill(tester, 'Nombre (opcional)', name);
        await tap(tester, find.text('Crear invitación'));
      }

      await tap(tester, find.text('Invitaciones'));
      await invite(' MOTORISTA@example.com ', 'Conductor', 'Motorista nueva');
      await invite('motorista@example.com', 'Ayudante', 'Duplicada');
      expect(
        find.text('Ya existe una invitación pendiente para este correo.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      Finder invitation(String email) =>
          find.ancestor(of: find.text(email), matching: find.byType(Card));
      Finder action(String email, String label) =>
          find.descendant(of: invitation(email), matching: find.text(label));
      await tap(tester, action('motorista@example.com', 'Simular aceptación'));
      await invite('asistente@example.com', 'Ayudante', 'Asistente nueva');
      await tap(tester, action('asistente@example.com', 'Simular aceptación'));
      await tap(tester, action('invitacion@demo.pe', 'Cancelar invitación'));
      expect(find.text('Ayudante · Cancelada'), findsOneWidget);

      await tap(tester, find.byIcon(Icons.menu));
      await tap(tester, find.text('Vehicles and teams'));
      await tap(tester, find.text('Equipos'));
      await tap(tester, find.text('Nuevo equipo'));
      expect(find.textContaining('Asistente nueva'), findsOneWidget);
      await tap(tester, find.text('Conductor principal'));
      expect(find.textContaining('Motorista nueva'), findsOneWidget);
      await tap(tester, find.textContaining('Motorista nueva').last);
      await tap(tester, find.text('Cancelar'));
      await tap(tester, find.byIcon(Icons.menu));
      await tap(tester, find.text('User management'));
      await fill(tester, 'Buscar por nombre o correo', 'motorista@example.com');
      expect(find.text('Motorista nueva'), findsOneWidget);
      await fill(tester, 'Buscar por nombre o correo', 'asistente@example.com');
      await tap(tester, find.text('Asistente nueva'));
      await tap(tester, find.text('Retirar acceso'));
      await tap(tester, find.text('Confirmar'));
      expect(find.text('Acceso inactivo'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Todos').last);
      await tap(tester, find.text('Activos').last);
      expect(find.text('Asistente nueva'), findsNothing);
      await tap(tester, find.text('Activos'));
      await tap(tester, find.text('Inactivos').last);
      expect(find.text('Asistente nueva'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
