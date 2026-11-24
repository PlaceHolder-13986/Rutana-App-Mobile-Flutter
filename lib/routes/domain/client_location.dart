/// Immutable snapshot when attached to a trip. A missing clientId denotes
/// a legacy location whose address remains usable without the catalog.
class ClientLocation {
  const ClientLocation({
    required this.id,
    required this.clientName,
    required this.siteName,
    required this.address,
    this.clientId,
    this.department = '',
    this.province = '',
    this.district = '',
    this.reference = '',
    this.contact = '',
    this.phone = '',
    this.latitude,
    this.longitude,
    this.isActive = true,
  });

  final String id, clientName, siteName, address;
  final String? clientId;
  final String department, province, district, reference, contact, phone;
  final double? latitude, longitude;
  final bool isActive;

  ClientLocation withClientName(String name) => ClientLocation(
    id: id,
    clientId: clientId,
    clientName: name,
    siteName: siteName,
    address: address,
    department: department,
    province: province,
    district: district,
    reference: reference,
    contact: contact,
    phone: phone,
    latitude: latitude,
    longitude: longitude,
    isActive: isActive,
  );

  String get contactLabel =>
      [contact, phone].where((v) => v.isNotEmpty).join(' · ');
}
