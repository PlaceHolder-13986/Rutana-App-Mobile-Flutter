import 'package:flutter/material.dart';

import '../../iam/domain/user.dart';
import '../../iam/data/user_repository.dart';
import '../../routes/data/trip_repository.dart';
import '../../routes/domain/trip.dart';
import '../data/fleet_repository.dart';

class FleetScreen extends StatefulWidget {
  final User? user;
  const FleetScreen({super.key, required this.user});
  @override
  State<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends State<FleetScreen> {
  final repo = FleetRepository.instance;
  final trips = TripRepository.instance;
  late Future<void> data;
  List<String> drivers = ['driver@demo.pe'];
  final helpers = <String>['helper@demo.pe'];
  String query = '', state = '', type = '';
  bool teams = false;
  User get user => widget.user!;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    data = load();
  }

  Future<void> load() async {
    if (widget.user == null) {
      throw StateError('Inicie sesión para consultar la flota.');
    }
    repo.vehicles(user);
    await trips.list(user);
    if (repo.canEdit(user)) {
      try {
        final users = await UserRepository().driversForCompany(user);
        drivers = users.isEmpty
            ? ['driver@demo.pe']
            : users.map((u) => u.email).toList();
      } catch (_) {
        drivers = ['driver@demo.pe'];
      }
    }
  }

  String assignments({String? plate, String? driver}) {
    final list = trips.assignments(user, plate: plate, driver: driver);
    if (list.isEmpty) return 'Sin asignaciones';
    final t = list.first;
    return '${t.status == TripStatus.inProgress ? 'En viaje · ' : ''}${t.id} · ${t.departure?.toLocal().toString().substring(0, 16) ?? 'Sin horario'}';
  }

  Future<void> detail(Vehicle? v, Crew? c) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(v?.plate ?? c!.name),
        content: SingleChildScrollView(
          child: Text(
            v != null
                ? '${v.type} · ${v.brand} ${v.model}\n${v.capacity} kg\n${vehicleStatusLabel(v.status)}\n${assignments(plate: v.plate)}\n'
                      '${trips.assignments(user, plate: v.plate).map((t) => '${t.id} · ${t.name} · ${t.departure}').join('\n')}'
                : 'Conductor: ${c!.driver}\nAyudantes: ${c.helpers.join(', ')}\n${c.active ? 'Activo' : 'Inactivo'}\n${assignments(driver: c.driver)}\n'
                      'Routes registra solo el conductor. La composición del equipo no modifica viajes anteriores.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          if (repo.canEdit(user))
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                edit(v, c);
              },
              child: const Text('Editar'),
            ),
        ],
      ),
    );
  }

  Future<void> edit(Vehicle? vehicle, Crew? crew) async {
    final isTeam = crew != null || (vehicle == null && teams);
    var plate = vehicle?.plate ?? '',
        kind = vehicle?.type ?? 'Camión',
        brand = vehicle?.brand ?? '',
        model = vehicle?.model ?? '',
        capacity = vehicle?.capacity.toString() ?? '',
        name = crew?.name ?? '',
        driver = crew?.driver ?? '';
    var status = vehicle?.status ?? VehicleStatus.enabled;
    var active = crew?.active ?? true;
    final selected = {...?crew?.helpers};
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) {
          Widget field(
            String label,
            String value,
            ValueChanged<String> change, {
            bool number = false,
          }) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              initialValue: value,
              decoration: InputDecoration(labelText: label),
              keyboardType: number ? TextInputType.number : TextInputType.text,
              onChanged: change,
            ),
          );
          return AlertDialog(
            title: Text(
              isTeam
                  ? (crew == null ? 'Nuevo equipo' : 'Editar equipo')
                  : (vehicle == null ? 'Nuevo vehículo' : 'Editar vehículo'),
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (!isTeam) ...[
                      field('Placa', plate, (v) => plate = v),
                      field('Tipo', kind, (v) => kind = v),
                      field('Marca', brand, (v) => brand = v),
                      field('Modelo', model, (v) => model = v),
                      field(
                        'Capacidad de carga (kg)',
                        capacity,
                        (v) => capacity = v,
                        number: true,
                      ),
                      DropdownButtonFormField<VehicleStatus>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'Estado operativo',
                        ),
                        items: VehicleStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(vehicleStatusLabel(s)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => status = v!,
                      ),
                    ] else ...[
                      field('Nombre del equipo', name, (v) => name = v),
                      DropdownButtonFormField<String>(
                        initialValue: drivers.contains(driver) ? driver : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Conductor principal',
                        ),
                        items: drivers
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                        onChanged: (v) => driver = v!,
                      ),
                      const Text(
                        'Ayudantes simulados · no existe este rol en usuarios',
                      ),
                      for (final h in helpers)
                        CheckboxListTile(
                          title: Text(h),
                          value: selected.contains(h),
                          onChanged: (v) => update(() {
                            v! ? selected.add(h) : selected.remove(h);
                          }),
                        ),
                      SwitchListTile(
                        title: const Text('Equipo activo'),
                        value: active,
                        onChanged: (v) => update(() => active = v),
                      ),
                      const Text(
                        'La edición solo cambia el catálogo. Routes conserva su conductor registrado.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  try {
                    if (isTeam) {
                      repo.saveCrew(
                        user,
                        id: crew?.id,
                        name: name,
                        driver: driver,
                        helpers: selected.toList(),
                        active: active,
                        drivers: drivers.toSet(),
                        helperOptions: helpers.toSet(),
                      );
                    } else {
                      repo.saveVehicle(
                        user,
                        id: vehicle?.id,
                        plate: plate,
                        type: kind,
                        brand: brand,
                        model: model,
                        capacity:
                            double.tryParse(capacity.replaceAll(',', '.')) ?? 0,
                        status: status,
                      );
                    }
                    Navigator.pop(dialog);
                    setState(() {});
                  } catch (e) {
                    update(() => error = e.toString());
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        TabBar(
          onTap: (i) => setState(() {
            teams = i == 1;
            query = '';
            state = '';
            type = '';
          }),
          tabs: const [
            Tab(text: 'Vehículos'),
            Tab(text: 'Equipos'),
          ],
        ),
        Expanded(
          child: FutureBuilder<void>(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${snapshot.error}'),
                      TextButton(
                        onPressed: () => setState(reload),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }
              final vehicles = repo.vehicles(user);
              final rows =
                  <
                    ({
                      String title,
                      String info,
                      String status,
                      String next,
                      VoidCallback open,
                    })
                  >[];
              if (teams) {
                for (final c in repo.crews(user)) {
                  final s = c.active ? 'Activo' : 'Inactivo';
                  if ('${c.name} ${c.driver}'.toLowerCase().contains(query) &&
                      (state.isEmpty || state == s)) {
                    rows.add((
                      title: c.name,
                      info: '${c.driver}\n${c.helpers.join(', ')}',
                      status: s,
                      next: assignments(driver: c.driver),
                      open: () => detail(null, c),
                    ));
                  }
                }
              } else {
                for (final v in vehicles) {
                  final s = vehicleStatusLabel(v.status);
                  if (FleetRepository.normalizePlate(v.plate)
                          .contains(FleetRepository.normalizePlate(query)) &&
                      (state.isEmpty || state == s) &&
                      (type.isEmpty || type == v.type)) {
                    rows.add((
                      title: v.plate,
                      info: '${v.type} · ${v.capacity} kg',
                      status: s,
                      next: assignments(plate: v.plate),
                      open: () => detail(v, null),
                    ));
                  }
                }
              }
              Widget filter(
                String label,
                String value,
                Set<String> values,
                ValueChanged<String> change,
              ) => SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('$label-$teams-$value'),
                  initialValue: value,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: label),
                  items: ['', ...values]
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.isEmpty ? 'Todos' : s),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => change(v!)),
                ),
              );
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (repo.canEdit(user))
                          FilledButton.icon(
                            onPressed: () => edit(null, null),
                            icon: const Icon(Icons.add),
                            label: Text(
                              teams ? 'Nuevo equipo' : 'Nuevo vehículo',
                            ),
                          ),
                        const Text(
                          'Datos en memoria · se pierden al reiniciar',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: ValueKey(teams),
                      decoration: InputDecoration(
                        labelText: teams
                            ? 'Buscar equipo o conductor'
                            : 'Buscar placa',
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => query = v.toLowerCase()),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        filter(
                          'Estado',
                          state,
                          teams
                              ? {'Activo', 'Inactivo'}
                              : VehicleStatus.values
                                    .map(vehicleStatusLabel)
                                    .toSet(),
                          (v) => state = v,
                        ),
                        if (!teams)
                          filter(
                            'Tipo',
                            type,
                            vehicles.map((v) => v.type).toSet(),
                            (v) => type = v,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: rows.isEmpty
                          ? const Center(
                              child: Text('No se encontraron registros.'),
                            )
                          : LayoutBuilder(
                              builder: (context, size) => size.maxWidth < 900
                                  ? ListView(
                                      children: rows
                                          .map(
                                            (r) => Card(
                                              child: ListTile(
                                                title: Text(r.title),
                                                subtitle: Text(
                                                  '${r.info}\n${r.status}\n${r.next}',
                                                ),
                                                onTap: r.open,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    )
                                  : SingleChildScrollView(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          columns:
                                              [
                                                    teams ? 'Equipo' : 'Placa',
                                                    teams
                                                        ? 'Tripulación'
                                                        : 'Tipo / capacidad',
                                                    'Estado',
                                                    'Asignación',
                                                  ]
                                                  .map(
                                                    (s) => DataColumn(
                                                      label: Text(s),
                                                    ),
                                                  )
                                                  .toList(),
                                          rows: rows
                                              .map(
                                                (r) => DataRow(
                                                  cells:
                                                      [
                                                            r.title,
                                                            r.info,
                                                            r.status,
                                                            r.next,
                                                          ]
                                                          .map(
                                                            (s) => DataCell(
                                                              Text(s),
                                                              onTap: r.open,
                                                            ),
                                                          )
                                                          .toList(),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
