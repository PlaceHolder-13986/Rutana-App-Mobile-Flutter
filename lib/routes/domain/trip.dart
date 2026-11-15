import '../../fleet/data/fleet_repository.dart';
import 'client_location.dart';

enum TripStatus { draft, published, inProgress, completed }

enum DeliveryResult { completed, partial, failed }

class Cargo {
  String product;
  int planned;
  int delivered;
  Cargo(this.product, this.planned, {this.delivered = 0});
  Cargo copy() => Cargo(product, planned, delivered: delivered);
}

class Stop {
  String site;
  String address;
  String contact;
  List<Cargo> cargo;
  DeliveryResult? result;
  String reason = '';
  Stop(this.site, this.address, this.contact, this.cargo);
  int get pending => cargo.fold(0, (sum, c) => sum + c.planned - c.delivered);
  Stop copy() =>
      Stop(site, address, contact, cargo.map((c) => c.copy()).toList())
        ..result = result
        ..reason = reason;
}

class TripIncident {
  final String type, description;
  final String? stop;
  TripIncident(this.type, this.description, this.stop);
}

class Trip {
  final String id, company;
  String name = '', origin = '', plate = '', driver = '';
  String routeType = 'Reparto';
  String colorHex = '#003B70';
  DateTime? departure;
  TripStatus status = TripStatus.draft;
  bool loaded = false, dispatched = false;
  String pendingResolution = '';
  List<Stop> stops = [];
  List<ClientLocation> selectedLocations = [];
  Crew? assignedTeam;
  List<TripIncident> incidents = [];

  Trip(this.id, this.company);

  int get pending => stops.fold(0, (sum, s) => sum + s.pending);

  Trip copy() => Trip(id, company)
    ..name = name
    ..origin = origin
    ..plate = plate
    ..driver = driver
    ..routeType = routeType
    ..colorHex = colorHex
    ..departure = departure
    ..status = status
    ..loaded = loaded
    ..dispatched = dispatched
    ..pendingResolution = pendingResolution
    ..stops = stops.map((s) => s.copy()).toList()
    ..selectedLocations = List.of(selectedLocations)
    ..assignedTeam = assignedTeam
    ..incidents = List.of(incidents);
}
