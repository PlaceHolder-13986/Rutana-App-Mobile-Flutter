import '../../clients/domain/client.dart';
import '../../iam/domain/user.dart';
import '../domain/client_location.dart';

class ClientLocationRepository {
  static final instance = ClientLocationRepository();
  final _companies = <String, _CompanyCatalog>{};
  int _sequence = 0;

  static String company(User user) =>
      user.ruc.trim().isNotEmpty ? user.ruc.trim() : user.company.trim();

  bool canEdit(User? user) =>
      user != null && user.role == 'Administrator' && company(user).isNotEmpty;

  _CompanyCatalog _catalog(User? user, {bool write = false}) {
    if (user == null ||
        company(user).isEmpty ||
        !{'Administrator', 'Driver'}.contains(user.role) ||
        (write && !canEdit(user))) {
      throw StateError('No tienes permiso para acceder al catálogo.');
    }
    return _companies.putIfAbsent(company(user), _CompanyCatalog.new);
  }

  Future<List<Client>> load(User? user) async => clients(user);

  List<Client> clients(User? user) =>
      List.unmodifiable(_catalog(user).clients.values);

  Client client(User user, String id) =>
      _catalog(user).clients[id] ??
      (throw StateError('Cliente no encontrado.'));

  List<ClientLocation> sites(User user, String clientId) => List.unmodifiable(
    _catalog(user).sites.values.where((s) => s.clientId == clientId),
  );

  bool hasRuc(User user, String ruc, {String? exceptId}) =>
      clients(user).any((c) => c.ruc == ruc.trim() && c.id != exceptId);

  Future<Client> saveClient(
    User user, {
    String? id,
    required String legalName,
    required String ruc,
    String tradeName = '',
    String contact = '',
    String phone = '',
    String email = '',
    String notes = '',
  }) async {
    final catalog = _catalog(user, write: true);
    final previous = id == null ? null : client(user, id);
    if (legalName.trim().isEmpty ||
        !rucPattern.hasMatch(ruc.trim()) ||
        (email.trim().isNotEmpty && !emailPattern.hasMatch(email.trim()))) {
      throw StateError('Revisa el nombre, el formato del RUC y el correo.');
    }
    if (hasRuc(user, ruc, exceptId: id)) {
      throw StateError('Este RUC ya está registrado en tu empresa.');
    }
    final saved = Client(
      id: id ?? 'C-${++_sequence}',
      legalName: legalName.trim(),
      ruc: ruc.trim(),
      tradeName: tradeName.trim(),
      contact: contact.trim(),
      phone: phone.trim(),
      email: email.trim(),
      notes: notes.trim(),
      active: previous?.active ?? true,
    );
    catalog.clients[saved.id] = saved;
    return saved;
  }

  Future<void> setActive(User user, String id, bool active) async {
    final catalog = _catalog(user, write: true);
    final c = client(user, id);
    catalog.clients[id] = Client(
      id: c.id,
      legalName: c.legalName,
      ruc: c.ruc,
      tradeName: c.tradeName,
      contact: c.contact,
      phone: c.phone,
      email: c.email,
      notes: c.notes,
      active: active,
    );
  }

  Future<ClientLocation> saveSite(
    User user,
    String clientId, {
    String? id,
    required String name,
    required String address,
    String department = '',
    String province = '',
    String district = '',
    String reference = '',
    String contact = '',
    String phone = '',
    double? latitude,
    double? longitude,
    bool active = true,
  }) async {
    final catalog = _catalog(user, write: true);
    final owner = client(user, clientId);
    if (id != null && catalog.sites[id]?.clientId != clientId) {
      throw StateError('Sede no encontrada para este cliente.');
    }
    if (name.trim().isEmpty ||
        address.trim().isEmpty ||
        (latitude == null) != (longitude == null) ||
        (latitude != null && !validCoordinate(latitude, 90)) ||
        (longitude != null && !validCoordinate(longitude, 180))) {
      throw StateError('Revisa el nombre, la dirección y las coordenadas.');
    }
    final saved = ClientLocation(
      id: id ?? 'S-${++_sequence}',
      clientId: clientId,
      clientName: owner.legalName,
      siteName: name.trim(),
      address: address.trim(),
      department: department.trim(),
      province: province.trim(),
      district: district.trim(),
      reference: reference.trim(),
      contact: contact.trim(),
      phone: phone.trim(),
      latitude: latitude,
      longitude: longitude,
      isActive: active,
    );
    catalog.sites[saved.id] = saved;
    return saved;
  }

  String? inactiveReason(User user, ClientLocation snapshot) {
    if (snapshot.clientId == null) return null;
    final catalog = _catalog(user);
    final owner = catalog.clients[snapshot.clientId];
    if (owner == null || !owner.active)
      return 'Cliente inactivo o no disponible';
    final site = catalog.sites[snapshot.id];
    if (site == null || site.clientId != owner.id || !site.isActive) {
      return 'Sede inactiva o no disponible';
    }
    return null;
  }

  static final rucPattern = RegExp(r'^\d{11}$');
  static final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static bool validCoordinate(double value, double limit) =>
      value.isFinite && value.abs() <= limit;
}

class _CompanyCatalog {
  final clients = <String, Client>{
    'demo-client': const Client(
      id: 'demo-client',
      legalName: 'Transportes Ejemplo SAC (ficticio)',
      ruc: '00000000001',
    ),
  };

  final sites = <String, ClientLocation>{
    for (final (id, name, district, latitude, longitude) in [
      ('demo-callao', 'Almacén Callao', 'Callao', -12.05, -77.12),
      ('demo-ventanilla', 'Local Ventanilla', 'Ventanilla', -11.88, -77.13),
    ])
      id: ClientLocation(
        id: id,
        clientId: 'demo-client',
        clientName: 'Transportes Ejemplo SAC (ficticio)',
        siteName: name,
        address: 'Dirección ficticia · $district',
        department: 'Callao',
        province: 'Callao',
        district: district,
        contact: 'Contacto ficticio',
        latitude: latitude,
        longitude: longitude,
      ),
  };
}
