import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../fleet/data/fleet_repository.dart';
import '../../routes/data/trip_repository.dart';
import '../domain/company_access.dart';
import '../domain/company_member.dart';
import '../domain/user.dart';
import 'user_repository.dart';

class CompanyMembersRepository {
  static final instance = CompanyMembersRepository(
    UserRepository().usersForCompany,
  );

  CompanyMembersRepository(this._loadAccounts, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Future<List<User>> Function(User) _loadAccounts;
  final DateTime Function() _now;
  final _companies = <String, _Memberships>{};
  final revision = ValueNotifier(0);
  int _sequence = 0;

  static final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  _Memberships _company(User actor) {
    final key = CompanyAccess.company(actor);
    if (key.isEmpty) throw StateError('La sesión no tiene una empresa.');
    return _companies.putIfAbsent(key, () => _Memberships(_now()));
  }

  void requireAdmin(User? actor) {
    if (!CompanyAccess.canManage(actor)) {
      throw StateError(
        'Solo los administradores activos pueden gestionar usuarios.',
      );
    }
  }

  CompanyMember? _fromUser(User user) {
    final role = CompanyRole.fromCode(user.role);
    if (role == null) return null;
    return CompanyMember(
      email: CompanyAccess.email(user.email),
      name: user.fullName,
      phone: user.phone,
      role: role,
      hasAccount: true,
    );
  }

  Future<void> refresh(User actor) async {
    if (!CompanyAccess.canPlan(actor)) {
      throw StateError(
        'No tienes permiso para consultar el personal de la empresa.',
      );
    }
    final company = _company(actor);
    _import(company, actor);
    try {
      final accounts = await _loadAccounts(actor);
      for (final user in accounts) {
        if (CompanyAccess.company(user) == CompanyAccess.company(actor)) {
          _import(company, user);
        }
      }
    } on MissingPluginException {
      // Flutter widget tests and platforms without the local SQLite plugin.
    } on StateError catch (error) {
      if (!error.message.toString().contains(
        'databaseFactory not initialized',
      )) {
        rethrow;
      }
    }
  }

  void _import(_Memberships company, User user) {
    final member = _fromUser(user);
    if (member == null) return;
    final previous = company.members[member.email];
    if (previous == null || !previous.hasAccount) {
      company.demoEmails.remove(member.email);
      company.members[member.email] = member;
    }
  }

  List<CompanyMember> members(User actor) {
    requireAdmin(actor);
    return List.unmodifiable(_company(actor).members.values);
  }

  List<CompanyInvitation> invitations(User actor) {
    requireAdmin(actor);
    return List.unmodifiable(
      _company(actor).invitations.values.toList().reversed,
    );
  }

  InvitationStatus status(CompanyInvitation invitation) =>
      invitation.statusAt(_now());

  List<CompanyMember> eligible(User actor, CompanyRole role) {
    if (!CompanyAccess.canPlan(actor)) return [];
    return _company(actor).members.values
        .where((member) => member.active && member.role == role)
        .toList();
  }

  /// Older routes may reference email addresses that predate IAM.
  bool validStaff(User actor, String email, CompanyRole role) {
    if (email.trim().isEmpty) return false;
    final member = _company(actor).members[CompanyAccess.email(email)];
    return member == null || (member.active && member.role == role);
  }

  String staffLabel(
    User actor,
    String email,
    CompanyRole assignmentRole, {
    bool history = false,
  }) {
    if (email.isEmpty || !CompanyAccess.canRead(actor)) return email;
    final normalized = CompanyAccess.email(email);
    final company = _company(actor);
    final member = company.members[normalized];
    if (member == null || company.demoEmails.contains(normalized)) return email;
    final label = member.name.isEmpty || member.name == member.email
        ? member.email
        : '${member.name} · ${member.email}';
    return '$label · ${(history ? assignmentRole : member.role).label}';
  }

  String? invitationError(User actor, String value) {
    requireAdmin(actor);
    final email = CompanyAccess.email(value);
    if (!emailPattern.hasMatch(email)) return 'Ingresa un correo válido.';
    final company = _company(actor);
    if (company.members.containsKey(email)) {
      return 'Este correo ya pertenece a la empresa. Revisa su acceso en Usuarios.';
    }
    if (company.invitations.values.any(
      (i) => i.email == email && status(i) == InvitationStatus.pending,
    )) {
      return 'Ya existe una invitación pendiente para este correo.';
    }
    return null;
  }

  Future<void> invite(
    User actor,
    String email,
    CompanyRole role,
    String name,
  ) async {
    requireAdmin(actor);
    await refresh(actor);
    final error = invitationError(actor, email);
    if (error != null) throw StateError(error);
    final createdAt = _now();
    final invite = CompanyInvitation(
      id: 'I-${++_sequence}',
      email: CompanyAccess.email(email),
      name: name.trim(),
      role: role,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(days: 7)),
    );
    _company(actor).invitations[invite.id] = invite;
    revision.value++;
  }

  Future<void> resolveInvitation(
    User actor,
    String id, {
    required bool accept,
  }) async {
    requireAdmin(actor);
    if (accept) await refresh(actor);
    requireAdmin(actor);
    final company = _company(actor);
    final invitation = company.invitations[id];
    if (invitation == null || status(invitation) != InvitationStatus.pending) {
      throw StateError('La invitación ya no está pendiente.');
    }
    if (accept) {
      if (company.members.containsKey(invitation.email)) {
        throw StateError('Este correo ya pertenece a la empresa.');
      }
      company.members[invitation.email] = CompanyMember(
        email: invitation.email,
        name: invitation.name,
        role: invitation.role,
        joinedAt: _now(),
      );
    }
    company.invitations[id] = invitation.withStatus(
      accept ? InvitationStatus.accepted : InvitationStatus.cancelled,
    );
    revision.value++;
  }

  Future<void> changeAccess(
    User actor,
    String email,
    CompanyRole role,
    bool active,
  ) async {
    requireAdmin(actor);
    await refresh(actor);
    requireAdmin(actor);
    final company = _company(actor);
    final key = CompanyAccess.email(email);
    final member = company.members[key];
    if (member == null) throw StateError('No se encontró al miembro.');
    if (member.role == role && member.active == active) return;
    if (member.active &&
        member.role == CompanyRole.administrator &&
        (!active || role != CompanyRole.administrator) &&
        !company.members.values.any(
          (m) =>
              m.email != key &&
              m.active &&
              m.role == CompanyRole.administrator &&
              (!member.hasAccount || m.hasAccount),
        )) {
      throw StateError(
        'La empresa debe conservar al menos un administrador activo con cuenta local.',
      );
    }
    if (!active || role != member.role) {
      final trip = TripRepository.instance
          .assignments(actor)
          .where(
            (t) =>
                (CompanyAccess.email(t.driver) == key &&
                    (!active || role != CompanyRole.driver)) ||
                ((t.assignedTeam?.helpers.any(
                          (h) => CompanyAccess.email(h) == key,
                        ) ??
                        false) &&
                    (!active || role != CompanyRole.helper)),
          )
          .firstOrNull;
      if (trip != null) {
        throw StateError(
          'Atiende primero el viaje ${trip.id} · ${trip.name} en Routes. La asignación requiere a este miembro.',
        );
      }
      final team = FleetRepository.instance
          .crews(actor)
          .where(
            (c) =>
                c.active &&
                ((CompanyAccess.email(c.driver) == key &&
                        (!active || role != CompanyRole.driver)) ||
                    (c.helpers.any((h) => CompanyAccess.email(h) == key) &&
                        (!active || role != CompanyRole.helper))),
          )
          .firstOrNull;
      if (team != null) {
        throw StateError(
          'Reemplaza primero a este miembro en el equipo ${team.name} desde Vehicles and teams.',
        );
      }
    }
    company.members[key] = member.withAccess(role, active);
    if (member.hasAccount) CompanyAccess.update(actor, key, role, active);
    revision.value++;
  }
}

class _Memberships {
  _Memberships(DateTime now)
    : invitations = {
        'demo-invitation': CompanyInvitation(
          id: 'demo-invitation',
          email: 'invitacion@demo.pe',
          role: CompanyRole.helper,
          name: 'Invitación de demostración',
          createdAt: now,
          expiresAt: now.add(const Duration(days: 7)),
        ),
      };

  final members = <String, CompanyMember>{
    'coordinator@demo.pe': const CompanyMember(
      email: 'coordinator@demo.pe',
      name: 'Coordinador demo',
      role: CompanyRole.coordinator,
    ),
    'driver@demo.pe': const CompanyMember(
      email: 'driver@demo.pe',
      name: 'Conductor demo',
      role: CompanyRole.driver,
    ),
    'helper@demo.pe': const CompanyMember(
      email: 'helper@demo.pe',
      name: 'Ayudante demo',
      role: CompanyRole.helper,
    ),
  };

  final demoEmails = {
    'coordinator@demo.pe',
    'driver@demo.pe',
    'helper@demo.pe',
  };
  final Map<String, CompanyInvitation> invitations;
}
