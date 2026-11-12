import '../../iam/domain/user.dart';
import '../../routes/data/trip_repository.dart';

enum VehicleStatus { enabled, maintenance, inactive }

String vehicleStatusLabel(VehicleStatus s) =>
    ['Habilitado', 'En mantenimiento', 'Inactivo'][s.index];

class Vehicle {
  final String id, company, plate, type, brand, model;
  final double capacity;
  final VehicleStatus status;
  const Vehicle(
    this.id,
    this.company,
    this.plate,
    this.type,
    this.brand,
    this.model,
    this.capacity,
    this.status,
  );
}

class Crew {
  final String id, company, name, driver;
  final List<String> helpers;
  final bool active;
  Crew(
    this.id,
    this.company,
    this.name,
    this.driver,
    List<String> helpers,
    this.active,
  ) : helpers = List.unmodifiable(helpers);
}

class FleetRepository {
  static final instance = FleetRepository();
  final Map<String, List<Vehicle>> _vehicles = {};
  final Map<String, List<Crew>> _crews = {};
  int _sequence = 0;
  static String company(User u) =>
      u.ruc.trim().isNotEmpty ? u.ruc.trim() : u.company.trim();
  static String normalizePlate(String value) =>
      value.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  bool canEdit(User u) => u.role == 'Administrator';
  void check(User u, {bool edit = false}) {
    if (company(u).isEmpty ||
        !(u.role == 'Administrator' || u.role == 'Driver') ||
        (edit && !canEdit(u))) {
      throw StateError('No tiene permisos para esta operación.');
    }
  }

  List<Vehicle> vehicles(User u) {
    check(u);
    return List.unmodifiable(
      _vehicles.putIfAbsent(
        company(u),
        () => [
          Vehicle(
            'demo',
            company(u),
            'ABC-123',
            'Camión',
            'Demo',
            'Demo',
            10000,
            VehicleStatus.enabled,
          ),
        ],
      ),
    );
  }

  List<Crew> crews(User u) {
    check(u);
    return List.unmodifiable(_crews[company(u)] ?? []);
  }

  Vehicle saveVehicle(
    User u, {
    String? id,
    required String plate,
    required String type,
    required String brand,
    required String model,
    required double capacity,
    required VehicleStatus status,
  }) {
    check(u, edit: true);
    final list = vehicles(u);
    final normalized = normalizePlate(plate);
    if (normalized.isEmpty ||
        type.trim().isEmpty ||
        brand.trim().isEmpty ||
        model.trim().isEmpty ||
        !capacity.isFinite ||
        capacity <= 0) {
      throw StateError(
        'Complete los campos y use una capacidad mayor que cero.',
      );
    }
    if (list.any((v) => v.id != id && normalizePlate(v.plate) == normalized)) {
      throw StateError('La placa ya está registrada en esta empresa.');
    }
    for (final old in list.where((v) => v.id == id)) {
      final trips = TripRepository.instance.assignments(u, plate: old.plate);
      if (trips.isNotEmpty &&
          (old.status != status || normalizePlate(old.plate) != normalized)) {
        throw StateError(
          'El coordinador debe atender primero el viaje ${trips.first.id} · ${trips.first.name}.',
        );
      }
    }
    final v = Vehicle(
      id ?? 'V-${_sequence++}',
      company(u),
      normalized,
      type.trim(),
      brand.trim(),
      model.trim(),
      capacity,
      status,
    );
    final target = _vehicles[company(u)]!;
    target.removeWhere((e) => e.id == v.id);
    target.add(v);
    return v;
  }

  Crew saveCrew(
    User u, {
    String? id,
    required String name,
    required String driver,
    required List<String> helpers,
    required bool active,
    required Set<String> drivers,
    required Set<String> helperOptions,
  }) {
    check(u, edit: true);
    if (name.trim().isEmpty ||
        !drivers.contains(driver) ||
        helpers.any((h) => !helperOptions.contains(h)) ||
        {driver, ...helpers}.length != helpers.length + 1) {
      throw StateError(
        'Indique nombre y conductor válidos, sin repetir personas.',
      );
    }
    final c = Crew(
      id ?? 'E-${_sequence++}',
      company(u),
      name.trim(),
      driver,
      helpers,
      active,
    );
    final list = _crews.putIfAbsent(company(u), () => []);
    list.removeWhere((e) => e.id == c.id);
    list.add(c);
    return c;
  }
}
