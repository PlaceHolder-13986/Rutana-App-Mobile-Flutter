import 'package:flutter/material.dart';

import '../../clients/presentation/clients_screen.dart';
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

  String? _clientId, _siteId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _trip = widget.trip.copy();

    _nameController.text = _trip.name.isEmpty
        ? 'Ruta de Distribución'
        : _trip.name;
    _originController.text = _trip.origin.isEmpty
        ? 'Almacén Principal'
        : _trip.origin;
    _trip.departure ??= DateTime.now().add(const Duration(hours: 4));

    if (_trip.stops.isEmpty) {
      _trip.stops = _trip.selectedLocations
          .map(
            (site) => Stop.fromLocation(site, [Cargo('Entregas / Carga', 10)]),
          )
          .toList();
    }
    _trip.selectedLocations.clear();
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
      _showAlert(
        'Aviso de publicación',
        e.toString().replaceAll('StateError: ', ''),
      );
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

  Future<void> _openClients() async {
    await ClientsScreen.open(context, widget.user);
    if (mounted) setState(() {});
  }

  Widget _buildCatalogSelector() {
    final clients = _locationRepo
        .clients(widget.user)
        .where((c) => c.active)
        .toList();
    final clientId = clients.any((c) => c.id == _clientId) ? _clientId : null;
    final sites = clientId == null
        ? <ClientLocation>[]
        : _locationRepo
              .sites(widget.user, clientId)
              .where((s) => s.isActive)
              .toList();
    final siteId = sites.any((s) => s.id == _siteId) ? _siteId : null;
    final site = siteId == null
        ? null
        : sites.firstWhere((s) => s.id == siteId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Seleccionar ubicación',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(('client', clientId)),
              initialValue: clientId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cliente activo'),
              items: [
                for (final c in clients)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.legalName, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: clients.isEmpty
                  ? null
                  : (value) => setState(() {
                      _clientId = value;
                      _siteId = null;
                    }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(('site', clientId, siteId)),
              initialValue: siteId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sede activa'),
              items: [
                for (final s in sites)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(s.siteName, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: sites.isEmpty
                  ? null
                  : (value) => setState(() => _siteId = value),
            ),
            if (clients.isEmpty)
              const Text(
                'No hay clientes activos. Registra o activa un cliente con una sede activa.',
              ),
            if (clientId != null && sites.isEmpty)
              const Text(
                'Este cliente no tiene sedes activas. Registra o activa una sede.',
              ),
            if (site != null) ...[
              const SizedBox(height: 8),
              Text(site.address),
              if (site.contactLabel.isNotEmpty) Text(site.contactLabel),
              if (site.latitude != null)
                Text('${site.latitude}, ${site.longitude}'),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: site == null
                      ? null
                      : () => setState(() {
                          _trip.stops.add(
                            Stop.fromLocation(site, [
                              Cargo('Carga / Producto', 1),
                            ]),
                          );
                        }),
                  child: const Text('Añadir parada'),
                ),
                OutlinedButton(
                  onPressed: site == null
                      ? null
                      : () => setState(() {
                          _trip.originLocation = site;
                          _originController.text = site.address;
                        }),
                  child: const Text('Usar como origen'),
                ),
                TextButton(
                  onPressed: _openClients,
                  child: const Text('Administrar clientes y sedes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _locationStatus(ClientLocation? location) => location == null
      ? null
      : _locationRepo.inactiveReason(widget.user, location);

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
                            side: const BorderSide(
                              color: AppColors.navy,
                              width: 1.5,
                            ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
              children: [_buildLocationsAndStopsTab(), _buildTeamTab()],
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
                  onChanged: (_) {
                    if (_trip.originLocation != null) {
                      setState(() => _trip.originLocation = null);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Origin / pickup address',
                    hintText: 'Ej. Almacén Central Lima',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_trip.originLocation case final location?) ...[
                  Text('${location.siteName} · ${location.clientName}'),
                  if (_locationStatus(location) case final status?)
                    Text(status),
                  if (location.contactLabel.isNotEmpty)
                    Text(location.contactLabel),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _pickDepartureTime,
                    icon: const Icon(
                      Icons.access_time_outlined,
                      color: AppColors.navy,
                    ),
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
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.gray,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _trip.assignedTeam != null
                            ? 'Equipo asignado: ${_trip.assignedTeam!.name} (${_trip.plate})'
                            : 'Selecciona el equipo vehicular y conductor en la pestaña "Team".',
                        style: TextStyle(
                          color: _trip.assignedTeam != null
                              ? AppColors.navyDark
                              : AppColors.gray,
                          fontSize: 12,
                          fontWeight: _trip.assignedTeam != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _buildCatalogSelector(),
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
                  'Todavía no hay paradas. Selecciona una sede o añade una parada manual.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.gray),
                ),
              ),
            )
          else
            Column(
              children: List.generate(_trip.stops.length, (index) {
                return KeyedSubtree(
                  key: ObjectKey(_trip.stops[index]),
                  child: _buildStopCard(index),
                );
              }),
            ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _trip.stops.add(Stop('', '', '', [Cargo('Boxes', 1)]));
                });
              },
              icon: const Icon(
                Icons.add_location_alt_outlined,
                color: AppColors.navy,
              ),
              label: const Text(
                'Añadir parada manual',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyDark,
                ),
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

          if (stop.location case final location?) ...[
            Text('${stop.site} · ${location.clientName}'),
            Text(stop.address),
            if (stop.contact.isNotEmpty) Text(stop.contact),
            if (location.latitude != null)
              Text('${location.latitude}, ${location.longitude}'),
            if (_locationStatus(location) case final status?) Text(status),
          ] else ...[
            TextFormField(
              initialValue: stop.site,
              decoration: const InputDecoration(
                labelText: 'Nombre de la parada',
              ),
              onChanged: (v) => stop.site = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: stop.address,
              decoration: const InputDecoration(labelText: 'Dirección'),
              onChanged: (v) => stop.address = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: stop.contact,
              decoration: const InputDecoration(labelText: 'Contacto'),
              onChanged: (v) => stop.contact = v,
            ),
          ],
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
                    decoration: const InputDecoration(
                      labelText: 'Planned quantity',
                    ),
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
                      child: const Text(
                        'Remove product',
                        style: TextStyle(color: AppColors.navy),
                      ),
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
              child: const Text(
                'Add product',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
