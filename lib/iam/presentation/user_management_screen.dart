import 'package:flutter/material.dart';

import '../../fleet/data/fleet_repository.dart';
import '../../routes/data/trip_repository.dart';
import '../../routes/presentation/routes_screen.dart' show departureLabel;
import '../../shared/widgets/rutana_app_bar.dart';
import '../data/company_members_repository.dart';
import '../domain/company_access.dart';
import '../domain/company_member.dart';
import '../domain/user.dart';

final _members = CompanyMembersRepository.instance;

String _message(Object error) => error is StateError
    ? error.message.toString()
    : 'No se pudo completar la operación. Inténtalo de nuevo.';

String _date(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatCompactDate(date.toLocal());

List<String> _teams(User user, String email) => FleetRepository.instance
    .crews(user)
    .where(
      (crew) => [
        crew.driver,
        ...crew.helpers,
      ].map(CompanyAccess.email).contains(email),
    )
    .map((crew) => crew.active ? crew.name : '${crew.name} (inactivo)')
    .toList();

Future<bool> _confirm(
  BuildContext context,
  String title,
  String detail,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key, required this.user});
  final User? user;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late Future<void> _load;
  final _search = TextEditingController();
  String _role = '', _status = '';
  bool _working = false;
  User get _user => widget.user!;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<void> _fetch() async {
    _members.requireAdmin(widget.user);
    await _members.refresh(_user);
  }

  void _retry() {
    final future = _fetch();
    setState(() {
      _load = future;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> _resolve(
    CompanyInvitation invitation, {
    required bool accept,
  }) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _members.resolveInvitation(_user, invitation.id, accept: accept);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showError(Object error) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_message(error))));

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _load,
    builder: (context, snapshot) {
      if (!CompanyAccess.canManage(widget.user)) {
        return const Center(
          child: Text(
            'Solo los administradores activos pueden gestionar usuarios.',
          ),
        );
      }
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
                Text(_message(snapshot.error!)),
                TextButton(onPressed: _retry, child: const Text('Reintentar')),
              ],
            ),
          ),
        );
      }
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Usuarios'),
                Tab(text: 'Invitaciones'),
              ],
            ),
            Expanded(
              child: TabBarView(children: [_usersTab(), _invitationsTab()]),
            ),
          ],
        ),
      );
    },
  );

  Widget _usersTab() {
    final all = _members.members(_user);
    final query = _search.text.trim().toLowerCase();
    final visible = all.where(
      (m) =>
          (m.name.toLowerCase().contains(query) || m.email.contains(query)) &&
          (_role.isEmpty || m.role.code == _role) &&
          (_status.isEmpty || _status == (m.active ? 'active' : 'inactive')),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _inviteButton(),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Cambios de acceso en memoria · se pierden al reiniciar'),
        ),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Buscar por nombre o correo',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _filter('Rol', _role, {
              '': 'Todos',
              for (final r in CompanyRole.values) r.code: r.label,
            }, (value) => setState(() => _role = value)),
            _filter('Estado', _status, {
              '': 'Todos',
              'active': 'Activos',
              'inactive': 'Inactivos',
            }, (value) => setState(() => _status = value)),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              all.isEmpty
                  ? 'Todavía no hay usuarios.'
                  : 'No hay usuarios que coincidan con los filtros.',
            ),
          ),
        for (final member in visible)
          Card(
            child: ListTile(
              title: Text(member.name.isEmpty ? member.email : member.name),
              trailing: const Icon(Icons.chevron_right),
              subtitle: Text(
                [
                  member.email,
                  '${member.role.label} · ${member.active ? 'Activo' : 'Inactivo'}',
                  if (_teams(_user, member.email) case final teams
                      when teams.isNotEmpty)
                    teams.join(', '),
                ].join('\n'),
              ),
              onTap: () =>
                  _open(_MemberDetail(user: _user, email: member.email)),
            ),
          ),
      ],
    );
  }

  Widget _invitationsTab() {
    final invitations = _members.invitations(_user);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _inviteButton(),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Invitaciones simuladas. No se envían correos y los cambios se pierden al reiniciar.',
          ),
        ),
        if (_working) const LinearProgressIndicator(),
        if (invitations.isEmpty) const Text('Todavía no hay invitaciones.'),
        for (final invite in invitations)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invite.email,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${invite.role.label} · ${_members.status(invite).label}',
                  ),
                  Text('Creada el ${_date(context, invite.createdAt)}'),
                  if (_members.status(invite) == InvitationStatus.pending) ...[
                    Text('Vence el ${_date(context, invite.expiresAt)}'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _working
                              ? null
                              : () => _resolve(invite, accept: false),
                          child: const Text('Cancelar invitación'),
                        ),
                        OutlinedButton(
                          onPressed: _working
                              ? null
                              : () => _resolve(invite, accept: true),
                          child: const Text('Simular aceptación'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _inviteButton() => Align(
    alignment: Alignment.centerLeft,
    child: FilledButton.icon(
      onPressed: _working ? null : () => _open(_InviteForm(user: _user)),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      label: const Text('Invitar usuario'),
    ),
  );

  Widget _filter(
    String label,
    String current,
    Map<String, String> labels,
    ValueChanged<String> change,
  ) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final entry in labels.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (value) => change(value!),
    ),
  );
}

class _InviteForm extends StatefulWidget {
  const _InviteForm({required this.user});
  final User user;

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _form = GlobalKey<FormState>();
  String _email = '', _name = '';
  CompanyRole? _role;
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
      await _members.invite(widget.user, _email, _role!, _name);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const RutanaAppBar(title: 'Invitar usuario'),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const Text(
              'La invitación es una simulación. No se enviará un correo.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
              ),
              onChanged: (value) => _email = value,
              validator: (value) => CompanyAccess.canManage(widget.user)
                  ? _members.invitationError(widget.user, value ?? '')
                  : 'Ya no tienes permiso para invitar.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CompanyRole>(
              initialValue: _role,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: _roleOptions(),
              onChanged: _saving ? null : (value) => _role = value,
              validator: (value) => value == null ? 'Selecciona un rol.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Nombre (opcional)'),
              onChanged: (value) => _name = value,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_saving) const LinearProgressIndicator(),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Crear invitación'),
            ),
          ],
        ),
      ),
    ),
  );
}

List<DropdownMenuItem<CompanyRole>> _roleOptions() => [
  for (final role in CompanyRole.values)
    DropdownMenuItem(value: role, child: Text(role.label)),
];

class _MemberDetail extends StatefulWidget {
  const _MemberDetail({required this.user, required this.email});
  final User user;
  final String email;

  @override
  State<_MemberDetail> createState() => _MemberDetailState();
}

class _MemberDetailState extends State<_MemberDetail> {
  bool _saving = false;
  int _roleSelection = 0;
  String? _error;

  Future<void> _change(
    CompanyMember member,
    CompanyRole role,
    bool active,
  ) async {
    if (_saving || (role == member.role && active == member.active)) return;
    final title = active != member.active
        ? (active ? 'Reactivar acceso' : 'Retirar acceso')
        : 'Cambiar rol';
    final description = active != member.active
        ? (active
              ? '${member.email} recuperará el acceso a esta empresa como ${role.label}.'
              : '${member.email} perderá acceso a esta empresa. Sus viajes y registros anteriores se conservarán.')
        : '${member.email} pasará de ${member.role.label} a ${role.label} en esta empresa.';
    if (!await _confirm(context, title, description) || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _members.changeAccess(widget.user, member.email, role, active);
      if (mounted && !CompanyAccess.canManage(widget.user)) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CompanyAccess.canManage(widget.user)) {
      return const Scaffold(
        appBar: RutanaAppBar(title: 'Detalle del usuario'),
        body: Center(
          child: Text('Ya no tienes permiso para gestionar usuarios.'),
        ),
      );
    }
    final member = _members
        .members(widget.user)
        .firstWhere((m) => m.email == widget.email);
    final teams = _teams(widget.user, member.email);
    final trips = TripRepository.instance
        .assignments(widget.user)
        .where(
          (t) =>
              CompanyAccess.email(t.driver) == member.email ||
              (t.assignedTeam?.helpers
                      .map(CompanyAccess.email)
                      .contains(member.email) ??
                  false),
        );
    return Scaffold(
      appBar: const RutanaAppBar(title: 'Detalle del usuario'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(member.name.isEmpty ? member.email : member.name),
                  subtitle: Text(member.email),
                ),
                ListTile(
                  title: Text(member.role.label),
                  subtitle: Text(
                    member.active ? 'Acceso activo' : 'Acceso inactivo',
                  ),
                ),
                if (member.phone.isNotEmpty)
                  ListTile(
                    title: const Text('Teléfono'),
                    subtitle: Text(member.phone),
                  ),
                if (member.joinedAt case final joined?)
                  ListTile(
                    title: const Text('Fecha de incorporación'),
                    subtitle: Text(_date(context, joined)),
                  ),
                ListTile(
                  title: const Text('Equipos'),
                  subtitle: Text(
                    teams.isEmpty ? 'Sin equipo' : teams.join(', '),
                  ),
                ),
              ],
            ),
          ),
          if (trips.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Asignaciones vigentes'),
            for (final trip in trips)
              ListTile(
                title: Text('${trip.id} · ${trip.name}'),
                subtitle: Text(departureLabel(trip.departure)),
              ),
          ],
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_saving) const LinearProgressIndicator(),
          DropdownButtonFormField<CompanyRole>(
            key: ValueKey((member.role, _roleSelection)),
            initialValue: member.role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Cambiar rol'),
            items: _roleOptions(),
            onChanged: _saving
                ? null
                : (role) async {
                    await _change(member, role!, member.active);
                    if (mounted) setState(() => _roleSelection++);
                  },
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _saving
                ? null
                : () => _change(member, member.role, !member.active),
            child: Text(member.active ? 'Retirar acceso' : 'Reactivar acceso'),
          ),
        ],
      ),
    );
  }
}
