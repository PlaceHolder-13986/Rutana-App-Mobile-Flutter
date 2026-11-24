class ClientLocation {
  final String id;
  final String clientName;
  final String siteName;
  final String address;
  final double latitude;
  final double longitude;
  final bool isActive;

  const ClientLocation({
    required this.id,
    required this.clientName,
    required this.siteName,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.isActive = true,
  });

  ClientLocation copyWith({
    String? id,
    String? clientName,
    String? siteName,
    String? address,
    double? latitude,
    double? longitude,
    bool? isActive,
  }) {
    return ClientLocation(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      siteName: siteName ?? this.siteName,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
    );
  }
}
