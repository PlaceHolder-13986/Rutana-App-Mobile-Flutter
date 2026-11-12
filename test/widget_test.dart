import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutana_app_movil/home/presentation/home_screen.dart';
import 'package:rutana_app_movil/iam/domain/user.dart';
import 'package:rutana_app_movil/routes/data/trip_repository.dart';
import 'package:rutana_app_movil/routes/domain/trip.dart';

const admin = User(
  fullName: 'Planner',
  email: 'admin@test.pe',
  phone: '',
  company: 'Test',
  ruc: 'test-routes',
  password: '',
  role: 'Administrator',
);

void main() {
  test('Draft, publication, dispatch, partial delivery and closure', () async {
    final repo = TripRepository();
    final trip = (await repo.list(admin)).single;
    repo.save(admin, trip);
    expect((await repo.list(admin)).single.status, TripStatus.draft);
    repo.publish(admin, trip);
    expect(() => repo.start(admin, trip), throwsStateError);
    repo.confirmLoad(admin, trip);
    repo.dispatch(admin, trip);
    repo.start(admin, trip);
    expect(
      () => repo.deliver(admin, trip, 1, DeliveryResult.partial, [
        16,
      ], 'Shortage'),
      throwsStateError,
    );
    expect(
      () => repo.deliver(admin, trip, 1, DeliveryResult.partial, [13], ''),
      throwsStateError,
    );
    repo.deliver(admin, trip, 0, DeliveryResult.completed, [25], '');
    repo.deliver(admin, trip, 1, DeliveryResult.partial, [
      13,
    ], 'Two damaged boxes');
    expect(trip.stops[1].pending, 2);
    expect(trip.pending, 2);
    expect(() => repo.close(admin, trip, ''), throwsStateError);
    repo.close(admin, trip, 'Two boxes returned to Ate warehouse');
    expect(trip.status, TripStatus.completed);
  });
  test('Publication validation, company scope and permissions', () async {
    final repo = TripRepository();
    final draft = repo.create(admin);
    expect(() => repo.publish(admin, draft), throwsStateError);
    final trip = (await repo.list(admin)).single;
    const driver = User(
      fullName: 'Driver',
      email: 'other@test.pe',
      phone: '',
      company: 'Test',
      ruc: 'test-routes',
      password: '',
      role: 'Driver',
    );
    expect(await repo.list(driver), isEmpty);
    expect(() => repo.confirmLoad(driver, trip), throwsStateError);
    final other = Trip('other', 'another-company');
    expect(() => repo.save(admin, other), throwsStateError);
    repo.publish(admin, trip);
    final conflicting = trip.copy()..status = TripStatus.draft;
    final second = repo.create(admin)
      ..name = conflicting.name
      ..origin = conflicting.origin
      ..departure = conflicting.departure
      ..plate = conflicting.plate
      ..driver = conflicting.driver
      ..stops = conflicting.stops;
    expect(() => repo.publish(admin, second), throwsStateError);
  });
  testWidgets('Routes opens from drawer and draft can be resumed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
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
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Routes').last);
    await tester.pumpAndSettle();
    expect(find.text('New route'), findsOneWidget);
    await tester.tap(find.text('New route'));
    await tester.pumpAndSettle();
    expect(find.text('Save draft'), findsOneWidget);
    await tester.ensureVisible(find.text('Save draft'));
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('New route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
