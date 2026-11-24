import '../../iam/domain/user.dart';
import '../../iam/domain/company_access.dart';
import '../../iam/data/company_members_repository.dart';
import '../../fleet/data/fleet_repository.dart';
import '../domain/trip.dart';
import 'client_location_repository.dart';

/// Store de Rutana. Almacena rutas en memoria durante la ejecución de la app.
class TripRepository {
  static final instance = TripRepository();
  final Map<String, List<Trip>> _companies = {};
  int _sequence = 1;

  String company(User u) => CompanyAccess.company(u);

  bool canPlan(User u) => CompanyAccess.canPlan(u);

  bool canOperate(User u, Trip t) =>
      t.company == company(u) &&
      (CompanyAccess.canManage(u) ||
          (CompanyAccess.role(u) == CompanyRole.driver &&
              _sameEmail(t.driver, u.email)));

  bool _sameEmail(String a, String b) =>
      CompanyAccess.email(a) == CompanyAccess.email(b);

  bool canView(User u, Trip t) =>
      t.company == company(u) &&
      (canPlan(u) ||
          canOperate(u, t) ||
          (CompanyAccess.role(u) == CompanyRole.helper &&
              (t.assignedTeam?.helpers.any((h) => _sameEmail(h, u.email)) ??
                  false)));

  void check(User u, Trip t, {bool planning = false}) {
    if (company(u).isEmpty ||
        t.company != company(u) ||
        !(planning ? canPlan(u) : canOperate(u, t))) {
      throw StateError('You do not have permission for this route.');
    }
  }

  Future<List<Trip>> list(User u) async {
    final key = company(u);
    if (!CompanyAccess.canRead(u)) {
      throw StateError('No tienes acceso a esta empresa.');
    }
    final trips = _companies.putIfAbsent(key, () {
      final t = Trip('RT-${_sequence++}', key)
        ..name = 'Ate – Callao – Ventanilla'
        ..origin = 'Ate warehouse, Lima'
        ..departure = DateTime.now().add(const Duration(days: 1))
        ..plate = 'ABC-123'
        ..driver = CompanyAccess.role(u) == CompanyRole.driver
            ? u.email
            : 'driver@demo.pe'
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
    return trips.where((t) => canView(u, t)).toList();
  }

  List<Trip> assignments(User u, {String? plate, String? driver}) {
    if (!CompanyAccess.canRead(u)) {
      throw StateError('No tienes acceso a esta empresa.');
    }
    return (_companies[company(u)] ?? [])
        .where(
          (t) =>
              (CompanyAccess.role(u) != CompanyRole.helper || canView(u, t)) &&
              t.status != TripStatus.draft &&
              t.status != TripStatus.completed &&
              (plate == null ||
                  FleetRepository.normalizePlate(t.plate) ==
                      FleetRepository.normalizePlate(plate)) &&
              (driver == null || _sameEmail(t.driver, driver)),
        )
        .toList()
      ..sort(
        (a, b) => (a.departure ?? DateTime(2100)).compareTo(
          b.departure ?? DateTime(2100),
        ),
      );
  }

  Trip create(User u) {
    if (!canPlan(u) || company(u).isEmpty) {
      throw StateError('Planning permission required.');
    }
    return Trip('RT-${_sequence++}', company(u));
  }

  void save(User u, Trip t) {
    check(u, t, planning: true);
    if (t.status != TripStatus.draft) {
      throw StateError('Only drafts can be edited.');
    }
    final list = _companies.putIfAbsent(t.company, () => []);
    final i = list.indexWhere((e) => e.id == t.id);
    if (i < 0) {
      list.add(t);
    } else {
      list[i] = t;
    }
  }

  void _checkCatalogAssignments(User u, Trip t) {
    final snapshots = [
      ?t.originLocation,
      for (final stop in t.stops) ?stop.location,
      if (t.stops.isEmpty) ...t.selectedLocations,
    ];
    for (final location in snapshots) {
      final reason = ClientLocationRepository.instance.inactiveReason(
        u,
        location,
      );
      if (reason != null) throw StateError('$reason: ${location.siteName}.');
    }
  }

  bool canAssignCrew(User u, Crew crew) {
    final members = CompanyMembersRepository.instance;
    return crew.company == company(u) &&
        crew.active &&
        members.validStaff(u, crew.driver, CompanyRole.driver) &&
        crew.helpers.every((h) => members.validStaff(u, h, CompanyRole.helper));
  }

  String? _staffConflict(Trip other, Trip candidate, String driver) {
    final reserved = [
      other.driver,
      ...?other.assignedTeam?.helpers,
    ].map(CompanyAccess.email).where((email) => email.isNotEmpty).toSet();
    return [driver, ...?candidate.assignedTeam?.helpers]
        .where((email) => reserved.contains(CompanyAccess.email(email)))
        .firstOrNull;
  }

  void _checkStaff(User u, Trip t, String driver) {
    final crew = t.assignedTeam;
    if (!CompanyMembersRepository.instance.validStaff(
          u,
          driver,
          CompanyRole.driver,
        ) ||
        (crew != null && !canAssignCrew(u, crew))) {
      throw StateError(
        'Selecciona un conductor y ayudantes activos con el rol correspondiente.',
      );
    }
    if (crew != null) {
      final current = FleetRepository.instance
          .crews(u)
          .where((c) => c.id == crew.id)
          .firstOrNull;
      if (current != null &&
          (!canAssignCrew(u, current) ||
              !_sameEmail(current.driver, crew.driver) ||
              current.helpers.length != crew.helpers.length ||
              !current.helpers.toSet().containsAll(crew.helpers))) {
        throw StateError(
          'El equipo cambió. Vuelve a seleccionarlo en la pestaña Team.',
        );
      }
    }
  }

  void returnToDraft(User u, Trip t) {
    check(u, t, planning: true);
    if (t.status != TripStatus.published || t.dispatched) {
      throw StateError('Solo puedes volver a borrador antes del despacho.');
    }
    t.status = TripStatus.draft;
    t.loaded = false;
  }

  void publishFromPlanning(User u, Trip t) {
    check(u, t, planning: true);
    _checkCatalogAssignments(u, t);
    if ((t.stops.isEmpty && t.selectedLocations.isEmpty) ||
        t.stops.any((s) => s.site.trim().isEmpty || s.address.trim().isEmpty) ||
        (t.assignedTeam == null && t.driver.isEmpty)) {
      throw StateError(
        'Route incomplete: Add at least one location and an assigned team to publish',
      );
    }

    final selectedDriver = t.assignedTeam?.driver ?? t.driver;
    final selectedPlate = t.plate.isEmpty ? 'ABC-123' : t.plate;
    _checkStaff(u, t, selectedDriver);

    for (final other in assignments(u)) {
      if (other.id == t.id) continue;
      final sameVehicle =
          FleetRepository.normalizePlate(other.plate) ==
          FleetRepository.normalizePlate(selectedPlate);
      final conflict = _staffConflict(other, t, selectedDriver);
      if (sameVehicle || conflict != null) {
        final resource = sameVehicle
            ? 'Vehículo $selectedPlate'
            : 'Miembro $conflict';
        throw StateError(
          '$resource tiene conflicto con ${other.id} · ${other.name}.',
        );
      }
    }

    t.driver = selectedDriver;
    t.plate = selectedPlate;
    if (t.stops.isEmpty) {
      t.stops = t.selectedLocations.map((loc) {
        return Stop.fromLocation(loc, [Cargo('Entregas / Carga', 10)]);
      }).toList();
    }
    save(u, t);
    t.status = TripStatus.published;
  }

  void publish(User u, Trip t) {
    check(u, t, planning: true);
    _checkCatalogAssignments(u, t);
    if (t.status != TripStatus.draft ||
        t.name.trim().isEmpty ||
        t.origin.trim().isEmpty ||
        t.departure == null ||
        t.stops.isEmpty ||
        !FleetRepository.instance
            .vehicles(u)
            .any(
              (v) =>
                  FleetRepository.normalizePlate(v.plate) ==
                      FleetRepository.normalizePlate(t.plate) &&
                  v.status == VehicleStatus.enabled,
            ) ||
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
    _checkStaff(u, t, t.driver);
    for (final other in assignments(u)) {
      if (other.id == t.id) continue;
      final sameVehicle =
          FleetRepository.normalizePlate(other.plate) ==
          FleetRepository.normalizePlate(t.plate);
      final conflict = _staffConflict(other, t, t.driver);
      if (sameVehicle || conflict != null) {
        final resource = sameVehicle
            ? 'Vehículo ${t.plate}'
            : _sameEmail(conflict!, t.driver)
            ? 'Conductor ${t.driver}'
            : 'Miembro $conflict';
        throw StateError(
          '$resource tiene conflicto con ${other.id} · ${other.name}. '
          'Cierre ese viaje primero: no hay hora de llegada para calcular intervalos.',
        );
      }
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
    if (!t.loaded || t.status != TripStatus.published) {
      throw StateError('Confirm loading first.');
    }
    t.dispatched = true;
  }

  void start(User u, Trip t) {
    check(u, t);
    if (!t.dispatched || t.status != TripStatus.published) {
      throw StateError('Confirm dispatch first.');
    }
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
    if (t.status != TripStatus.inProgress) {
      throw StateError('Start the trip first.');
    }
    final s = t.stops[index];
    if (s.result != null || quantities.length != s.cargo.length) {
      throw StateError('Delivery already recorded.');
    }
    for (var i = 0; i < quantities.length; i++) {
      if (quantities[i] < 0 || quantities[i] > s.cargo[i].planned) {
        throw StateError('Delivered quantity must be within planned quantity.');
      }
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
        (t.pending > 0 && resolution.trim().isEmpty)) {
      throw StateError(
        'Record all results and document pending cargo disposition.',
      );
    }
    t.pendingResolution = resolution.trim();
    t.status = TripStatus.completed;
  }

  void report(User u, Trip t, TripIncident incident) {
    check(u, t);
    if (incident.type.isEmpty || incident.description.trim().isEmpty) {
      throw StateError('Type and description required.');
    }
    t.incidents.add(incident);
  }
}
