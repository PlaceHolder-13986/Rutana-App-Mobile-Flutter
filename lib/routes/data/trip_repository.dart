import '../../iam/domain/user.dart';
import '../domain/trip.dart';

/// Demo store. Data survives navigation, but is lost when the process exits.
class TripRepository {
  static final instance = TripRepository();
  final Map<String, List<Trip>> _companies = {};
  int _sequence = 1;
  String company(User u) =>
      u.ruc.trim().isNotEmpty ? u.ruc.trim() : u.company.trim();
  bool canPlan(User u) => u.role == 'Administrator';
  bool canOperate(User u, Trip t) =>
      canPlan(u) || (u.role == 'Driver' && t.driver == u.email);
  void check(User u, Trip t, {bool planning = false}) {
    if (company(u).isEmpty ||
        t.company != company(u) ||
        !(planning ? canPlan(u) : canOperate(u, t))) {
      throw StateError('You do not have permission for this route.');
    }
  }

  Future<List<Trip>> list(User u) async {
    final key = company(u);
    if (key.isEmpty) throw StateError('A company is required.');
    final trips = _companies.putIfAbsent(key, () {
      final t = Trip('RT-${_sequence++}', key)
        ..name = 'Ate – Callao – Ventanilla'
        ..origin = 'Ate warehouse, Lima'
        ..departure = DateTime.now().add(const Duration(days: 1))
        ..plate = 'ABC-123'
        ..driver = u.role == 'Driver' ? u.email : 'driver@demo.pe'
        ..stops = [
          Stop('Callao', 'Av. Argentina, Callao', 'Dispatch · 999111222', [
            Cargo('Boxes', 25),
          ]),
          Stop(
            'Ventanilla',
            'Av. Néstor Gambetta, Ventanilla',
            'Reception · 999333444',
            [Cargo('Boxes', 15)],
          ),
        ];
      return [t];
    });
    return trips
        .where((t) => canPlan(u) || (u.role == 'Driver' && t.driver == u.email))
        .toList();
  }

  Trip create(User u) {
    if (!canPlan(u) || company(u).isEmpty)
      throw StateError('Planning permission required.');
    return Trip('RT-${_sequence++}', company(u));
  }

  void save(User u, Trip t) {
    check(u, t, planning: true);
    if (t.status != TripStatus.draft)
      throw StateError('Only drafts can be edited.');
    final list = _companies.putIfAbsent(t.company, () => []);
    final i = list.indexWhere((e) => e.id == t.id);
    if (i < 0) {
      list.add(t);
    } else {
      list[i] = t;
    }
  }

  void publish(User u, Trip t) {
    check(u, t, planning: true);
    if (t.status != TripStatus.draft ||
        t.name.trim().isEmpty ||
        t.origin.trim().isEmpty ||
        t.departure == null ||
        t.stops.isEmpty ||
        t.plate != 'ABC-123' ||
        t.driver.isEmpty ||
        t.stops.any(
          (s) =>
              s.site.isEmpty ||
              s.address.trim().isEmpty ||
              s.cargo.isEmpty ||
              s.cargo.any((c) => c.product.trim().isEmpty || c.planned <= 0),
        )) {
      throw StateError(
        'Provide name, origin, departure, delivery cargo, enabled vehicle and driver.',
      );
    }
    if ((_companies[t.company] ?? []).any(
      (other) =>
          other.id != t.id &&
          other.status != TripStatus.draft &&
          other.status != TripStatus.completed &&
          (other.plate == t.plate || other.driver == t.driver),
    )) {
      throw StateError(
        'Vehicle or driver is assigned to another active route.',
      );
    }
    save(u, t);
    t.status = TripStatus.published;
  }

  void confirmLoad(User u, Trip t) {
    check(u, t, planning: true);
    if (t.status != TripStatus.published) throw StateError('Publish first.');
    t.loaded = true;
  }

  void dispatch(User u, Trip t) {
    check(u, t, planning: true);
    if (!t.loaded || t.status != TripStatus.published)
      throw StateError('Confirm loading first.');
    t.dispatched = true;
  }

  void start(User u, Trip t) {
    check(u, t);
    if (!t.dispatched || t.status != TripStatus.published)
      throw StateError('Confirm dispatch first.');
    t.status = TripStatus.inProgress;
  }

  void deliver(
    User u,
    Trip t,
    int index,
    DeliveryResult result,
    List<int> quantities,
    String reason,
  ) {
    check(u, t);
    if (t.status != TripStatus.inProgress)
      throw StateError('Start the trip first.');
    final s = t.stops[index];
    if (s.result != null || quantities.length != s.cargo.length)
      throw StateError('Delivery already recorded.');
    for (var i = 0; i < quantities.length; i++) {
      if (quantities[i] < 0 || quantities[i] > s.cargo[i].planned)
        throw StateError('Delivered quantity must be within planned quantity.');
    }
    final total = quantities.fold(0, (int a, b) => a + b);
    final planned = s.cargo.fold(0, (int a, c) => a + c.planned);
    if ((result == DeliveryResult.completed && total != planned) ||
        (result == DeliveryResult.partial &&
            (total == 0 || total == planned)) ||
        (result == DeliveryResult.failed && total != 0) ||
        (result != DeliveryResult.completed && reason.trim().isEmpty)) {
      throw StateError('Result, quantities and reason must agree.');
    }
    for (var i = 0; i < quantities.length; i++) {
      s.cargo[i].delivered = quantities[i];
    }
    s.result = result;
    s.reason = reason.trim();
  }

  void close(User u, Trip t, String resolution) {
    check(u, t);
    if (t.status != TripStatus.inProgress ||
        t.stops.any((s) => s.result == null) ||
        (t.pending > 0 && resolution.trim().isEmpty))
      throw StateError(
        'Record all results and document pending cargo disposition.',
      );
    t.pendingResolution = resolution.trim();
    t.status = TripStatus.completed;
  }

  void report(User u, Trip t, TripIncident incident) {
    check(u, t);
    if (incident.type.isEmpty || incident.description.trim().isEmpty)
      throw StateError('Type and description required.');
    t.incidents.add(incident);
  }
}
