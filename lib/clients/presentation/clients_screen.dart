import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../iam/domain/user.dart';
import '../../routes/data/client_location_repository.dart';
import '../../routes/domain/client_location.dart';
import '../../shared/widgets/rutana_app_bar.dart';
import '../domain/client.dart';

final _repository = ClientLocationRepository.instance;

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.user});
  final User? user;

  static Future<void> open(BuildContext context, User user) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: const RutanaAppBar(title: 'Clients'),
            body: ClientsScreen(user: user),
          ),
        ),
      );

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

enum _ClientFilter { all, active, inactive }

class _ClientsScreenState extends State<ClientsScreen> {
  late Future<List<Client>> _data;
  final _search = TextEditingController();
  String get _query => _search.text.trim().toLowerCase();
  var _filter = _ClientFilter.all;

  @override
  void initState() {
    super.initState();
    _data = _repository.load(widget.user);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _data = _repository.load(widget.user));

  Future<void> _open({Client? client}) async {
    final user = widget.user!;
    if (client == null) {
      client = await Navigator.of(context).push<Client>(
        MaterialPageRoute(builder: (_) => _ClientForm(user: user)),
      );
      if (client == null || !mounted) return;
      _reload();
    }
    final id = client.id;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ClientDetail(user: user, clientId: id),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Client>>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorMessage(snapshot.error!)),
                TextButton(onPressed: _reload, child: const Text('Reintentar')),
              ],
            ),
          ),
        );
      }
      final clients = snapshot.requireData;
      final visible = clients.where(
        (c) =>
            (switch (_filter) {
              _ClientFilter.all => true,
              _ClientFilter.active => c.active,
              _ClientFilter.inactive => !c.active,
            }) &&
            [
              c.legalName,
              c.tradeName,
              c.ruc,
            ].any((v) => v.toLowerCase().contains(_query)),
      );
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          if (_repository.canEdit(widget.user))
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _open(),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo cliente'),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Datos en memoria · se pierden al reiniciar'),
          ),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Buscar por razón social, nombre comercial o RUC',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<_ClientFilter>(
            initialValue: _filter,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: const [
              DropdownMenuItem(value: _ClientFilter.all, child: Text('Todos')),
              DropdownMenuItem(
                value: _ClientFilter.active,
                child: Text('Activos'),
              ),
              DropdownMenuItem(
                value: _ClientFilter.inactive,
                child: Text('Inactivos'),
              ),
            ],
            onChanged: (value) => setState(() => _filter = value!),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                clients.isEmpty ? 'Todavía no hay clientes.' : 'No hay clientes que coincidan con la búsqueda o el filtro.',
              ),
            ),
          for (final c in visible)
            Card(
              child: ListTile(
                onTap: () => _open(client: c),
                title: Text(c.legalName),
                trailing: const Icon(Icons.chevron_right),
                subtitle: Text(
                  [
                    if (c.tradeName.isNotEmpty) c.tradeName,
                    'RUC ${c.ruc}',
                    if (c.contact.isNotEmpty) c.contact,
                    if (c.phone.isNotEmpty) c.phone,
                    '${_repository.sites(widget.user!, c.id).length} sedes · ${_status(c.active)}',
                  ].join('\n'),
                ),
              ),
            ),
        ],
      );
    },
  );
}

String _status(bool active) => active ? 'Activo' : 'Inactivo';
String _errorMessage(Object error) => error is StateError
    ? error.message.toString()
    : 'No se pudo completar la operación. Inténtalo de nuevo.';

class _ClientDetail extends StatefulWidget {
  const _ClientDetail({required this.user, required this.clientId});
  final User user;
  final String clientId;

  @override
  State<_ClientDetail> createState() => _ClientDetailState();
}

class _ClientDetailState extends State<_ClientDetail> {
  bool _saving = false;

  Future<void> _edit(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> _changeStatus(Client c) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repository.setActive(widget.user, c.id, !c.active);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _repository.client(widget.user, widget.clientId);
    final sites = _repository.sites(widget.user, c.id);
    final canEdit = _repository.canEdit(widget.user);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const RutanaAppBar(title: 'Detalle del cliente'),
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Información'),
                Tab(text: 'Sedes'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_saving) const LinearProgressIndicator(),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(c.legalName),
                              subtitle: Text(_status(c.active)),
                            ),
                            ListTile(
                              title: const Text('RUC'),
                              subtitle: Text(c.ruc),
                            ),
                            for (final (label, value) in [
                              ('Nombre comercial', c.tradeName),
                              ('Contacto principal', c.contact),
                              ('Teléfono', c.phone),
                              ('Correo electrónico', c.email),
                              ('Observaciones', c.notes),
                            ])
                              if (value.isNotEmpty)
                                ListTile(
                                  title: Text(label),
                                  subtitle: Text(value),
                                ),
                          ],
                        ),
                      ),
                      if (canEdit)
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () => _edit(
                                      _ClientForm(user: widget.user, client: c),
                                    ),
                              child: const Text('Editar cliente'),
                            ),
                            OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => _changeStatus(c),
                              child: Text(
                                c.active
                                    ? 'Desactivar cliente'
                                    : 'Activar cliente',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (canEdit)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: () => _edit(
                              _SiteForm(user: widget.user, clientId: c.id),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Nueva sede'),
                          ),
                        ),
                      if (sites.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Este cliente aún no tiene sedes.'),
                        ),
                      for (final site in sites)
                        Card(
                          child: ListTile(
                            title: Text(site.siteName),
                            subtitle: Text(
                              [
                                site.address,
                                [
                                  site.department,
                                  site.province,
                                  site.district,
                                ].where((v) => v.isNotEmpty).join(' · '),
                                if (site.reference.isNotEmpty) site.reference,
                                if (site.contactLabel.isNotEmpty)
                                  site.contactLabel,
                                if (site.latitude != null)
                                  '${site.latitude}, ${site.longitude}',
                                _status(site.isActive),
                              ].where((v) => v.isNotEmpty).join('\n'),
                            ),
                            trailing: canEdit
                                ? IconButton(
                                    tooltip: 'Editar sede',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _edit(
                                      _SiteForm(
                                        user: widget.user,
                                        clientId: c.id,
                                        site: site,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field {
  const _Field(
    this.label,
    this.initial, {
    this.validator,
    this.keyboard,
    this.formatters,
    this.lines = 1,
    this.helper,
  });

  final String label, initial;
  final String? Function(String)? validator;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final int lines;
  final String? helper;
}

String? _required(String value) =>
    value.trim().isEmpty ? 'Completa este campo.' : null;

class _ClientForm extends StatelessWidget {
  const _ClientForm({required this.user, this.client});
  final User user;
  final Client? client;

  @override
  Widget build(BuildContext context) {
    final c = client;
    return _CatalogForm<Client>(
      title: c == null ? 'Nuevo cliente' : 'Editar cliente',
      fields: [
        _Field('Razón social', c?.legalName ?? '', validator: _required),
        _Field('Nombre comercial', c?.tradeName ?? ''),
        _Field(
          'RUC',
          c?.ruc ?? '',
          keyboard: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          helper: 'Validación local de formato: 11 dígitos.',
          validator: (value) {
            if (!ClientLocationRepository.rucPattern.hasMatch(value.trim()))
              return 'Ingresa 11 dígitos.';
            if (_repository.hasRuc(user, value, exceptId: c?.id))
              return 'Este RUC ya está registrado en tu empresa.';
            return null;
          },
        ),
        _Field('Contacto principal', c?.contact ?? ''),
        _Field('Teléfono', c?.phone ?? '', keyboard: TextInputType.phone),
        _Field(
          'Correo electrónico',
          c?.email ?? '',
          keyboard: TextInputType.emailAddress,
          validator: (v) =>
              v.trim().isEmpty ||
                  ClientLocationRepository.emailPattern.hasMatch(v.trim())
              ? null
              : 'Ingresa un correo válido.',
        ),
        _Field('Observaciones', c?.notes ?? '', lines: 3),
      ],
      onSave: (v, _) => _repository.saveClient(
        user,
        id: c?.id,
        legalName: v['Razón social']!,
        tradeName: v['Nombre comercial']!,
        ruc: v['RUC']!,
        contact: v['Contacto principal']!,
        phone: v['Teléfono']!,
        email: v['Correo electrónico']!,
        notes: v['Observaciones']!,
      ),
    );
  }
}

double? _coordinate(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

class _SiteForm extends StatelessWidget {
  const _SiteForm({required this.user, required this.clientId, this.site});
  final User user;
  final String clientId;
  final ClientLocation? site;

  @override
  Widget build(BuildContext context) {
    final s = site;
    String? coordinateError(String text, double limit) {
      if (text.trim().isEmpty) return null;
      final number = _coordinate(text);
      return number != null &&
              ClientLocationRepository.validCoordinate(number, limit)
          ? null
          : 'Ingresa un valor entre -$limit y $limit.';
    }

    const coordinates = TextInputType.numberWithOptions(
      signed: true,
      decimal: true,
    );
    return _CatalogForm<ClientLocation>(
      title: s == null ? 'Nueva sede' : 'Editar sede',
      initialActive: s?.isActive ?? true,
      fields: [
        _Field('Nombre de la sede', s?.siteName ?? '', validator: _required),
        _Field('Dirección', s?.address ?? '', validator: _required),
        _Field('Departamento', s?.department ?? ''),
        _Field('Provincia', s?.province ?? ''),
        _Field('Distrito', s?.district ?? ''),
        _Field('Referencia', s?.reference ?? ''),
        _Field('Contacto de la sede', s?.contact ?? ''),
        _Field('Teléfono', s?.phone ?? '', keyboard: TextInputType.phone),
        _Field(
          'Latitud',
          s?.latitude?.toString() ?? '',
          keyboard: coordinates,
          validator: (v) => coordinateError(v, 90),
        ),
        _Field(
          'Longitud',
          s?.longitude?.toString() ?? '',
          keyboard: coordinates,
          validator: (v) => coordinateError(v, 180),
        ),
      ],
      onSave: (v, active) => _repository.saveSite(
        user,
        clientId,
        id: s?.id,
        name: v['Nombre de la sede']!,
        address: v['Dirección']!,
        department: v['Departamento']!,
        province: v['Provincia']!,
        district: v['Distrito']!,
        reference: v['Referencia']!,
        contact: v['Contacto de la sede']!,
        phone: v['Teléfono']!,
        latitude: _coordinate(v['Latitud']!),
        longitude: _coordinate(v['Longitud']!),
        active: active!,
      ),
    );
  }
}

class _CatalogForm<T> extends StatefulWidget {
  const _CatalogForm({
    required this.title,
    required this.fields,
    required this.onSave,
    this.initialActive,
  });
  final String title;
  final List<_Field> fields;
  final Future<T> Function(Map<String, String>, bool?) onSave;
  final bool? initialActive;

  @override
  State<_CatalogForm<T>> createState() => _CatalogFormState<T>();
}

class _CatalogFormState<T> extends State<_CatalogForm<T>> {
  final _form = GlobalKey<FormState>();
  late final Map<String, String> _values = {
    for (final field in widget.fields) field.label: field.initial,
  };
  late bool? _active = widget.initialActive;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.onSave(_values, _active);
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: RutanaAppBar(title: widget.title),
    body: SafeArea(
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_saving) const LinearProgressIndicator(),
              for (final field in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    enabled: !_saving,
                    initialValue: field.initial,
                    maxLines: field.lines,
                    keyboardType: field.keyboard,
                    inputFormatters: field.formatters,
                    decoration: InputDecoration(
                      labelText: field.label,
                      helperText: field.helper,
                    ),
                    onChanged: (value) => _values[field.label] = value,
                    validator: (value) {
                      final text = value ?? '';
                      final other = switch (field.label) {
                        'Latitud' => _values['Longitud'],
                        'Longitud' => _values['Latitud'],
                        _ => null,
                      };
                      if (text.trim().isEmpty &&
                          (other?.trim().isNotEmpty ?? false))
                        return 'Ingresa ambas coordenadas.';
                      return field.validator?.call(text);
                    },
                  ),
                ),
              if (_active != null)
                SwitchListTile(
                  title: const Text('Sede activa'),
                  value: _active!,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _active = v),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
