import 'package:flutter/material.dart';

import '../../fleet/data/fleet_repository.dart';
import '../../iam/domain/user.dart';
import '../../shared/theme/app_colors.dart';
import '../data/client_location_repository.dart';
import '../data/trip_repository.dart';
import '../domain/client_location.dart';
import '../domain/trip.dart';

class RoutePlanningScreen extends StatefulWidget {
  final User user;
  final Trip trip;

  const RoutePlanningScreen({
    super.key,
    required this.user,
    required this.trip,
  });

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Trip _trip;
  final _locationRepo = ClientLocationRepository.instance;
  final _fleetRepo = FleetRepository.instance;

  final _nameController = TextEditingController();
  final _originController = TextEditingController();

  String _searchQuery = '';
  late ClientLocation _focusedLocation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _trip = widget.trip.copy();

    _nameController.text = _trip.name.isEmpty ? 'Ruta de Distribución' : _trip.name;
    _originController.text = _trip.origin.isEmpty ? 'Almacén Principal' : _trip.origin;
    _trip.departure ??= DateTime.now().add(const Duration(hours: 4));

    final locations = _locationRepo.list();
    _focusedLocation = locations.isNotEmpty
        ? locations.first
        : const ClientLocation(
            id: 'P-001',
            clientName: 'ACME Corp',
            siteName: 'Main Warehouse',
            address: 'Av. Industrial 123, Lima',
            latitude: -12.0464,
            longitude: -77.0428,
          );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _originController.dispose();
    super.dispose();
  }

  void _syncTripHeaderFields() {
    _trip.name = _nameController.text.trim();
    _trip.origin = _originController.text.trim();
  }

  void _saveDraft() {
    _syncTripHeaderFields();
    setState(() => _isSaving = true);
    try {
      TripRepository.instance.save(widget.user, _trip);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Borrador guardado correctamente.'),
          backgroundColor: AppColors.navy,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showAlert('Error al guardar borrador', e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _publishRoute() {
    _syncTripHeaderFields();
    setState(() => _isSaving = true);

    if (_trip.stops.isEmpty && _trip.selectedLocations.isEmpty) {
      _showAlert(
        'Aviso de publicación',
        'Route incomplete: Add at least one location and an assigned team to publish',
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      TripRepository.instance.publishFromPlanning(widget.user, _trip);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ruta ${_trip.id} publicada exitosamente. Conductor notificado.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showAlert('Aviso de publicación', e.toString().replaceAll('StateError: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  bool _isLocationSelected(ClientLocation loc) {
    return _trip.stops.any((s) => s.site == loc.siteName || s.address == loc.address) ||
        _trip.selectedLocations.any((l) => l.id == loc.id);
  }

  void _toggleSelectLocation(ClientLocation loc) {
    setState(() {
      if (_isLocationSelected(loc)) {
        _trip.selectedLocations.removeWhere((l) => l.id == loc.id);
        _trip.stops.removeWhere((s) => s.site == loc.siteName || s.address == loc.address);
      } else {
        _trip.selectedLocations.add(loc);
        _trip.stops.add(
          Stop(
            loc.siteName,
            loc.address,
            'Contacto · ${loc.clientName}',
            [Cargo('Carga / Producto', 1)],
          ),
        );
      }
    });
  }

  Future<void> _pickDepartureTime() async {
    final current = _trip.departure ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time != null && mounted) {
      setState(() {
        _trip.departure = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  String _formatDeparture(DateTime? d) {
    if (d == null) return 'Not scheduled';
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Route ${_trip.id}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Perfil de usuario')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Subheader con Pestañas y Acciones Principales (Punto Único de Guardado/Publicación)
          Container(
            color: const Color(0xFFEFEFEF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.navy, width: 1.5),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.navyDark,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'Locations & Stops'),
                      Tab(text: 'Team'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _saveDraft,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navyDark,
                            side: const BorderSide(color: AppColors.navy, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save draft',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _publishRoute,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.yellow,
                            foregroundColor: AppColors.navyDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 1,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Publish route',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Contenido principal de las Pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLocationsAndStopsTab(),
                _buildTeamTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: LOCATIONS & STOPS
  // ---------------------------------------------------------------------------
  Widget _buildLocationsAndStopsTab() {
    final allLocations = _locationRepo.list(query: _searchQuery);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Route name',
                    hintText: 'Ej. Ate - Callao - Ventanilla',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _originController,
                  decoration: const InputDecoration(
                    labelText: 'Origin / pickup address',
                    hintText: 'Ej. Almacén Central Lima',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _pickDepartureTime,
                    icon: const Icon(Icons.access_time_outlined, color: AppColors.navy),
                    label: Text(
                      'Departure: ${_formatDeparture(_trip.departure)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyDark,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      side: const BorderSide(color: AppColors.navy, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppColors.gray),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _trip.assignedTeam != null
                            ? 'Equipo asignado: ${_trip.assignedTeam!.name} (${_trip.plate})'
                            : 'Selecciona el equipo vehicular y conductor en la pestaña "Team".',
                        style: TextStyle(
                          color: _trip.assignedTeam != null ? AppColors.navyDark : AppColors.gray,
                          fontSize: 12,
                          fontWeight: _trip.assignedTeam != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Sección de Búsqueda y Mapa Interactivo
          TextField(
            decoration: InputDecoration(
              hintText: 'Search client',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.grey),
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 12),

          GestureDetector(
            onTap: () {
              if (allLocations.isNotEmpty) {
                final nextIdx = (allLocations.indexOf(_focusedLocation) + 1) % allLocations.length;
                setState(() => _focusedLocation = allLocations[nextIdx]);
              }
            },
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFE6EEF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB0BEC5)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 44, color: AppColors.navy),
                  SizedBox(height: 6),
                  Text(
                    'Interactive Map',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.navyDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap on the map to create a new location',
                    style: TextStyle(color: AppColors.gray, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tarjeta de Detalles de Ubicación Enfocada
          _buildLocationDetailsCard(_focusedLocation),
          const SizedBox(height: 24),

          // Sección de Delivery Stops (Detalles de Paradas e Itinerario)
          const Text(
            'Delivery stops · order defines itinerary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.navyDark,
            ),
          ),
          const SizedBox(height: 12),

          if (_trip.stops.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Center(
                child: Text(
                  'No delivery stops added yet. Select a location from the map or add a stop manually.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.gray),
                ),
              ),
            )
          else
            Column(
              children: List.generate(_trip.stops.length, (index) {
                return _buildStopCard(index);
              }),
            ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _trip.stops.add(
                    Stop(
                      'Callao',
                      'Av. Argentina, Callao',
                      'Dispatch · 999111222',
                      [Cargo('Boxes', 1)],
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add_location_alt_outlined, color: AppColors.navy),
              label: const Text(
                'Add delivery stop',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyDark),
              ),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                side: const BorderSide(color: AppColors.navy),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDetailsCard(ClientLocation loc) {
    final isSelected = _isLocationSelected(loc);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Location Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.navyDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ID', style: TextStyle(color: AppColors.gray, fontSize: 11)),
                    Text(loc.id, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text('Direction', style: TextStyle(color: AppColors.gray, fontSize: 11)),
                    Text(loc.siteName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text('Latitude', style: TextStyle(color: AppColors.gray, fontSize: 11)),
                    Text(loc.latitude.toStringAsFixed(4), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Client', style: TextStyle(color: AppColors.gray, fontSize: 11)),
                    Text(loc.clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text('Address', style: TextStyle(color: AppColors.gray, fontSize: 11)),
                    Text(loc.address, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text('Longitude', style: TextStyle(color: AppColors.gray, fontSize: 11)),
                    Text(loc.longitude.toStringAsFixed(4), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: isSelected ? null : () => _toggleSelectLocation(loc),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Select'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: !isSelected ? null : () => _toggleSelectLocation(loc),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navyDark,
                      side: const BorderSide(color: AppColors.navy),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Unselect'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStopCard(int index) {
    final stop = _trip.stops[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stop ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.navyDark,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    tooltip: 'Move up',
                    onPressed: index == 0
                        ? null
                        : () {
                            setState(() {
                              final item = _trip.stops.removeAt(index);
                              _trip.stops.insert(index - 1, item);
                            });
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Remove stop',
                    onPressed: () {
                      setState(() {
                        _trip.stops.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            initialValue: ['Callao', 'Ventanilla', 'Miraflores'].contains(stop.site)
                ? stop.site
                : null,
            decoration: const InputDecoration(
              labelText: 'Client site (demo)',
            ),
            items: ['Callao', 'Ventanilla', 'Miraflores']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  stop.site = v;
                  if (v == 'Callao') stop.address = 'Av. Argentina, Callao';
                  if (v == 'Ventanilla') stop.address = 'Av. Néstor Gambetta, Ventanilla';
                  if (v == 'Miraflores') stop.address = 'Av. Benavides 1020, Miraflores';
                });
              }
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            initialValue: stop.address,
            decoration: const InputDecoration(labelText: 'Address'),
            onChanged: (v) => stop.address = v,
          ),
          const SizedBox(height: 12),

          TextFormField(
            initialValue: stop.contact,
            decoration: const InputDecoration(labelText: 'Contact'),
            onChanged: (v) => stop.contact = v,
          ),
          const SizedBox(height: 12),

          // Lista de Productos
          ...List.generate(stop.cargo.length, (pIndex) {
            final cargo = stop.cargo[pIndex];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: cargo.product,
                    decoration: const InputDecoration(labelText: 'Product'),
                    onChanged: (v) => cargo.product = v,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: cargo.planned.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Planned quantity'),
                    onChanged: (v) => cargo.planned = int.tryParse(v) ?? 1,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          stop.cargo.removeAt(pIndex);
                        });
                      },
                      child: const Text('Remove product', style: TextStyle(color: AppColors.navy)),
                    ),
                  ),
                ],
              ),
            );
          }),

          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () {
                setState(() {
                  stop.cargo.add(Cargo('Boxes', 1));
                });
              },
              child: const Text('Add product', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: TEAM
  // ---------------------------------------------------------------------------
  Widget _buildTeamTab() {
    final crews = _fleetRepo.crews(widget.user);
    final vehicles = _fleetRepo.vehicles(widget.user);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available teams',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.navyDark,
            ),
          ),
          const SizedBox(height: 12),

          if (crews.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Center(
                child: Text(
                  'No teams available in Fleet. Please create a team first.',
                  style: TextStyle(color: AppColors.gray),
                ),
              ),
            )
          else
            Column(
              children: crews.map((crew) {
                final isSelected = _trip.assignedTeam?.id == crew.id;
                final vehiclePlate = vehicles.isNotEmpty
                    ? vehicles.first.plate
                    : 'XYZ-123';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.navy : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.local_shipping_outlined,
                                color: AppColors.navyDark,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                vehiclePlate,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.navyDark,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _trip.assignedTeam = crew;
                                  _trip.driver = crew.driver;
                                  _trip.plate = vehiclePlate;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? AppColors.navyDark
                                    : AppColors.navy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(isSelected ? 'Selected' : 'Select'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Team members',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        crew.driver,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      for (final helper in crew.helpers)
                        Text(
                          helper,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
