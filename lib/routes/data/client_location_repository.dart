import '../domain/client_location.dart';

class ClientLocationRepository {
  static final instance = ClientLocationRepository();

  final List<ClientLocation> _locations = [
    const ClientLocation(
      id: 'P-001',
      clientName: 'ACME Corp',
      siteName: 'Main Warehouse',
      address: 'Av. Industrial 123, Lima',
      latitude: -12.0464,
      longitude: -77.0428,
      isActive: true,
    ),
    const ClientLocation(
      id: 'P-002',
      clientName: 'ACME Corp',
      siteName: 'North Branch',
      address: 'Jr. Los Olivos 456, Lima',
      latitude: -11.9833,
      longitude: -77.0667,
      isActive: true,
    ),
    const ClientLocation(
      id: 'P-003',
      clientName: 'Distribuidora Lima',
      siteName: 'Distribution Center',
      address: 'Av. Pachacútec 789, Callao',
      latitude: -12.0500,
      longitude: -77.1167,
      isActive: true,
    ),
    const ClientLocation(
      id: 'P-004',
      clientName: 'Corporación Sur',
      siteName: 'South Warehouse',
      address: 'Av. Benavides 1020, Miraflores',
      latitude: -12.1222,
      longitude: -77.0283,
      isActive: true,
    ),
  ];

  List<ClientLocation> list({String query = ''}) {
    if (query.trim().isEmpty) {
      return List.unmodifiable(_locations);
    }
    final q = query.toLowerCase();
    return List.unmodifiable(
      _locations.where(
        (l) =>
            l.clientName.toLowerCase().contains(q) ||
            l.siteName.toLowerCase().contains(q) ||
            l.address.toLowerCase().contains(q) ||
            l.id.toLowerCase().contains(q),
      ),
    );
  }
}
