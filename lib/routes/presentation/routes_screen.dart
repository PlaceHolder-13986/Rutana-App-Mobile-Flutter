import 'package:flutter/material.dart';

import '../../iam/domain/user.dart';
import '../../iam/data/user_repository.dart';
import '../domain/trip.dart';
import '../data/trip_repository.dart';

String statusLabel(TripStatus s) =>
    ['Draft', 'Published', 'In progress', 'Completed'][s.index];
String departureLabel(DateTime? d) =>
    d == null ? 'Not scheduled' : d.toLocal().toString().substring(0, 16);

class RoutesScreen extends StatefulWidget {
  final User? user;
  const RoutesScreen({super.key, required this.user});
  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final repo = TripRepository.instance;
  late Future<List<Trip>> data;
  String query = '';
  TripStatus? filter;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    data = widget.user == null
        ? Future.error('Sign in to view routes.')
        : repo.list(widget.user!);
  }

  Future<void> open(Trip trip, {bool edit = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => edit
            ? TripEditor(user: widget.user!, trip: trip)
            : TripDetail(user: widget.user!, trip: trip),
      ),
    );
    if (mounted) {
      setState(reload);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.user != null && repo.canPlan(widget.user!))
              FilledButton.icon(
                onPressed: () => open(repo.create(widget.user!), edit: true),
                icon: const Icon(Icons.add),
                label: const Text('New route'),
              ),
            const Text('Demo data · stored in memory'),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search code, destination or plate',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v.toLowerCase()),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TripStatus>(
          initialValue: filter,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All')),
            ...TripStatus.values.map(
              (s) => DropdownMenuItem(value: s, child: Text(statusLabel(s))),
            ),
          ],
          onChanged: (v) => setState(() => filter = v),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Trip>>(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${snapshot.error}'),
                      TextButton(
                        onPressed: () => setState(reload),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              final trips = snapshot.data!
                  .where(
                    (t) =>
                        (filter == null || t.status == filter) &&
                        '${t.id} ${t.plate} ${t.stops.map((s) => s.site).join(' ')}'
                            .toLowerCase()
                            .contains(query),
                  )
                  .toList();
              if (trips.isEmpty)
                return const Center(child: Text('No routes found.'));
              return LayoutBuilder(
                builder: (context, size) {
                  if (size.maxWidth < 1000)
                    return ListView(
                      children: trips
                          .map(
                            (t) => Card(
                              child: ListTile(
                                title: Text('${t.id} · ${t.name}'),
                                subtitle: Text(
                                  '${departureLabel(t.departure)}\n${t.origin} → ${t.stops.map((s) => s.site).join(' → ')}\n${t.plate} · ${t.driver}\n${t.stops.where((s) => s.result != null).length}/${t.stops.length} stops · ${statusLabel(t.status)}',
                                ),
                                isThreeLine: false,
                                onTap: () => open(t),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  return SingleChildScrollView(
                    child: SizedBox(
                      width: size.maxWidth,
                      child: DataTable(
                        columnSpacing: 12,
                        columns: const [
                          DataColumn(label: Text('Route / departure')),
                          DataColumn(label: Text('Itinerary')),
                          DataColumn(label: Text('Vehicle / driver')),
                          DataColumn(label: Text('Progress / status')),
                        ],
                        rows: trips
                            .map(
                              (t) => DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        '${t.id} · ${t.name}\n${departureLabel(t.departure)}',
                                      ),
                                    ),
                                    onTap: () => open(t),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 230,
                                      child: Text(
                                        '${t.origin} → ${t.stops.map((s) => s.site).join(' → ')}',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    onTap: () => open(t),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        '${t.plate}\n${t.driver}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    onTap: () => open(t),
                                  ),
                                  DataCell(
                                    Text(
                                      '${t.stops.where((s) => s.result != null).length}/${t.stops.length} · ${statusLabel(t.status)}',
                                    ),
                                    onTap: () => open(t),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class TripEditor extends StatefulWidget {
  final User user;
  final Trip trip;
  const TripEditor({super.key, required this.user, required this.trip});
  @override
  State<TripEditor> createState() => _TripEditorState();
}

class _TripEditorState extends State<TripEditor> {
  late Trip draft;
  List<String> drivers = [];
  String? driverNotice;
  String? error;
  @override
  void initState() {
    super.initState();
    draft = widget.trip.copy();
    UserRepository()
        .driversForCompany(widget.user)
        .then((users) {
          if (mounted)
            setState(() => drivers = users.map((u) => u.email).toList());
        })
        .catchError((Object e) {
          if (mounted)
            setState(
              () => driverNotice =
                  'Local users unavailable; demo driver available.',
            );
        });
  }

  Widget field(
    String label,
    String value,
    ValueChanged<String> change, {
    bool number = false,
    Key? key,
  }) => Padding(
    key: key,
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      keyboardType: number ? TextInputType.number : TextInputType.text,
      onChanged: change,
    ),
  );
  void save(bool publish) {
    try {
      final repo = TripRepository.instance;
      if (publish) {
        repo.publish(widget.user, draft);
      } else {
        repo.save(widget.user, draft);
      }
      Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Route ${draft.id}')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        field('Route name', draft.name, (v) => draft.name = v),
        field('Origin / pickup address', draft.origin, (v) => draft.origin = v),
        OutlinedButton(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: draft.departure ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(
                draft.departure ?? DateTime.now(),
              ),
            );
            if (time != null)
              setState(
                () => draft.departure = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                ),
              );
          },
          child: Text('Departure: ${departureLabel(draft.departure)}'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: draft.plate.isEmpty ? null : draft.plate,
          decoration: const InputDecoration(
            labelText: 'Enabled vehicle (demo)',
          ),
          items: const [
            DropdownMenuItem(
              value: 'ABC-123',
              child: Text('ABC-123 · enabled'),
            ),
          ],
          onChanged: (v) => draft.plate = v ?? '',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: draft.driver.isEmpty ? null : draft.driver,
          decoration: const InputDecoration(
            labelText: 'Driver · company users / demo',
          ),
          isExpanded: true,
          items: {
            'driver@demo.pe',
            ...drivers,
            if (draft.driver.isNotEmpty) draft.driver,
          }.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => draft.driver = v ?? '',
        ),
        const SizedBox(height: 16),
        if (driverNotice != null) Text(driverNotice!),
        const Text('Delivery stops · order defines itinerary'),
        for (var i = 0; i < draft.stops.length; i++) stopEditor(i),
        OutlinedButton.icon(
          onPressed: () => setState(
            () => draft.stops.add(
              Stop('Callao', 'Av. Argentina, Callao', 'Dispatch · 999111222', [
                Cargo('Boxes', 1),
              ]),
            ),
          ),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add delivery stop'),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed: () => save(false),
              child: const Text('Save draft'),
            ),
            FilledButton(
              onPressed: () => save(true),
              child: const Text('Publish route'),
            ),
          ],
        ),
      ],
    ),
  );
  Widget stopEditor(int i) {
    final s = draft.stops[i];
    return Card(
      key: ObjectKey(s),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text('Stop ${i + 1}')),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: i == 0
                      ? null
                      : () => setState(() {
                          draft.stops.removeAt(i);
                          draft.stops.insert(i - 1, s);
                        }),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Remove stop',
                  onPressed: () => setState(() => draft.stops.removeAt(i)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: s.site,
              decoration: const InputDecoration(
                labelText: 'Client site (demo)',
              ),
              items: [
                'Callao',
                'Ventanilla',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() {
                s.site = v!;
                s.address = v == 'Callao'
                    ? 'Av. Argentina, Callao'
                    : 'Av. Néstor Gambetta, Ventanilla';
              }),
            ),
            const SizedBox(height: 12),
            field(
              'Address',
              s.address,
              (v) => s.address = v,
              key: ValueKey(s.site),
            ),
            field('Contact', s.contact, (v) => s.contact = v),
            for (final c in s.cargo)
              Column(
                key: ObjectKey(c),
                children: [
                  field('Product', c.product, (v) => c.product = v),
                  field(
                    'Planned quantity',
                    c.planned.toString(),
                    (v) => c.planned = int.tryParse(v) ?? 0,
                    number: true,
                  ),
                  TextButton(
                    onPressed: () => setState(() => s.cargo.remove(c)),
                    child: const Text('Remove product'),
                  ),
                ],
              ),
            TextButton(
              onPressed: () => setState(() => s.cargo.add(Cargo('', 1))),
              child: const Text('Add product'),
            ),
          ],
        ),
      ),
    );
  }
}

class TripDetail extends StatefulWidget {
  final User user;
  final Trip trip;
  const TripDetail({super.key, required this.user, required this.trip});
  @override
  State<TripDetail> createState() => _TripDetailState();
}

class _TripDetailState extends State<TripDetail> {
  final repo = TripRepository.instance;
  Trip get t => widget.trip;
  void act(VoidCallback action) {
    try {
      action();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget button(String label, VoidCallback action) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: FilledButton(onPressed: () => act(action), child: Text(label)),
  );
  @override
  Widget build(BuildContext context) {
    final plan = repo.canPlan(widget.user),
        operate = repo.canOperate(widget.user, t);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${t.id} · ${statusLabel(t.status)}'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Itinerary'),
              Tab(text: 'Cargo & dispatch'),
              Tab(text: 'Tracking'),
              Tab(text: 'Incidents'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(t.name, style: Theme.of(context).textTheme.headlineSmall),
                Text(
                  'Departure: ${departureLabel(t.departure)}\nVehicle: ${t.plate}\nDriver: ${t.driver}',
                ),
                ListTile(
                  leading: const Icon(Icons.warehouse_outlined),
                  title: Text(t.origin),
                  subtitle: const Text('Pickup origin'),
                ),
                for (var i = 0; i < t.stops.length; i++)
                  ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(t.stops[i].site),
                    subtitle: Text(
                      '${t.stops[i].address}\n${t.stops[i].contact}\nETA unavailable · ${t.stops[i].result?.name ?? 'Pending'}',
                    ),
                  ),
                if (plan && t.status == TripStatus.draft)
                  button('Resume draft', () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => TripEditor(user: widget.user, trip: t),
                      ),
                    );
                    if (context.mounted) Navigator.pop(context);
                  }),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Pickup total: ${t.stops.fold<int>(0, (a, s) => a + s.cargo.fold<int>(0, (b, c) => b + c.planned))} units',
                ),
                for (final s in t.stops)
                  Card(
                    child: ListTile(
                      title: Text(s.site),
                      subtitle: Text(
                        s.cargo
                            .map((c) => '${c.product}: ${c.planned}')
                            .join('\n'),
                      ),
                    ),
                  ),
                Text(
                  'Loading: ${t.loaded ? 'Confirmed' : 'Pending'} · Dispatch: ${t.dispatched ? 'Confirmed' : 'Pending'}',
                ),
                if (plan && t.status == TripStatus.published && !t.loaded)
                  button(
                    'Confirm loading',
                    () => repo.confirmLoad(widget.user, t),
                  ),
                if (plan &&
                    t.status == TripStatus.published &&
                    t.loaded &&
                    !t.dispatched)
                  button(
                    'Confirm dispatch',
                    () => repo.dispatch(widget.user, t),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${t.stops.where((s) => s.result != null).length}/${t.stops.length} stops recorded · ${t.pending} units pending',
                ),
                LinearProgressIndicator(
                  value: t.stops.isEmpty
                      ? 0
                      : t.stops.where((s) => s.result != null).length /
                            t.stops.length,
                ),
                if (operate && t.status == TripStatus.published && t.dispatched)
                  button('Start trip', () => repo.start(widget.user, t)),
                for (var i = 0; i < t.stops.length; i++)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.stops[i].site),
                          for (final c in t.stops[i].cargo)
                            Text(
                              '${c.product}: ${c.delivered}/${c.planned} delivered · ${c.planned - c.delivered} pending',
                            ),
                          Text(
                            '${t.stops[i].result?.name ?? 'Pending'} · ${t.stops[i].reason}',
                          ),
                          if (operate &&
                              t.status == TripStatus.inProgress &&
                              t.stops[i].result == null)
                            TextButton(
                              onPressed: () => delivery(i),
                              child: const Text('Record delivery'),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (operate &&
                    t.status == TripStatus.inProgress &&
                    t.stops.every((s) => s.result != null))
                  button('Close trip', close),
                if (t.pendingResolution.isNotEmpty)
                  Text('Pending cargo disposition: ${t.pendingResolution}'),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (operate) button('Report incident', incident),
                if (t.incidents.isEmpty) const Text('No incidents reported.'),
                for (final e in t.incidents)
                  Card(
                    child: ListTile(
                      title: Text(e.type),
                      subtitle: Text(
                        '${e.stop ?? 'Whole route'}\n${e.description}',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> delivery(int index) async {
    final s = t.stops[index];
    final quantities = s.cargo.map((c) => c.planned).toList();
    var result = DeliveryResult.completed;
    var reason = '';
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Delivery · ${s.site}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null) Text(error!),
                  DropdownButtonFormField<DeliveryResult>(
                    initialValue: result,
                    items: DeliveryResult.values
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.name)),
                        )
                        .toList(),
                    onChanged: (v) => update(() => result = v!),
                  ),
                  for (var j = 0; j < s.cargo.length; j++)
                    TextFormField(
                      initialValue: quantities[j].toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            '${s.cargo[j].product} · planned ${s.cargo[j].planned}',
                      ),
                      onChanged: (v) => quantities[j] = int.tryParse(v) ?? -1,
                    ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Reason (required for partial / failed)',
                    ),
                    onChanged: (v) => reason = v,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  repo.deliver(
                    widget.user,
                    t,
                    index,
                    result,
                    quantities,
                    reason,
                  );
                  Navigator.pop(dialog);
                  setState(() {});
                } catch (e) {
                  update(() => error = e.toString());
                }
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> close() async {
    var resolution = '';
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Close trip'),
        content: TextField(
          decoration: InputDecoration(
            labelText: 'Disposition for ${t.pending} pending units',
          ),
          onChanged: (v) => resolution = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => act(() {
              repo.close(widget.user, t, resolution);
              Navigator.pop(dialog);
            }),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> incident() async {
    var type = 'Delay', description = '';
    String? stop;
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Report incident'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: ['Delay', 'Damage', 'Breakdown', 'Other']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => type = v!,
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Stop (optional)',
                  ),
                  items: t.stops
                      .asMap()
                      .entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key.toString(),
                          child: Text('${e.key + 1}. ${e.value.site}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      stop = v == null ? null : t.stops[int.parse(v)].site,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Description'),
                  onChanged: (v) => description = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => act(() {
              repo.report(
                widget.user,
                t,
                TripIncident(type, description, stop),
              );
              Navigator.pop(dialog);
            }),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
}
