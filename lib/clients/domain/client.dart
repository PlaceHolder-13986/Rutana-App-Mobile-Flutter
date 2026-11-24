class Client {
  const Client({
    required this.id,
    required this.legalName,
    required this.ruc,
    this.tradeName = '',
    this.contact = '',
    this.phone = '',
    this.email = '',
    this.notes = '',
    this.active = true,
  });

  final String id, legalName, ruc, tradeName, contact, phone, email, notes;
  final bool active;
}
