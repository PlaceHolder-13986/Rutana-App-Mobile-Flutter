import 'company_access.dart';

class CompanyMember {
  const CompanyMember({
    required this.email,
    required this.name,
    required this.role,
    this.phone = '',
    this.active = true,
    this.hasAccount = false,
    this.joinedAt,
  });

  final String email, name, phone;
  final CompanyRole role;
  final bool active, hasAccount;
  final DateTime? joinedAt;

  CompanyMember withAccess(CompanyRole nextRole, bool nextActive) =>
      CompanyMember(
        email: email,
        name: name,
        phone: phone,
        role: nextRole,
        active: nextActive,
        hasAccount: hasAccount,
        joinedAt: joinedAt,
      );
}

enum InvitationStatus {
  pending('Pendiente'),
  accepted('Aceptada'),
  cancelled('Cancelada'),
  expired('Vencida');

  const InvitationStatus(this.label);
  final String label;
}

class CompanyInvitation {
  const CompanyInvitation({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    required this.createdAt,
    required this.expiresAt,
    this.status = InvitationStatus.pending,
  });

  final String id, email, name;
  final CompanyRole role;
  final DateTime createdAt, expiresAt;
  final InvitationStatus status;

  InvitationStatus statusAt(DateTime time) =>
      status == InvitationStatus.pending && !time.isBefore(expiresAt)
      ? InvitationStatus.expired
      : status;

  CompanyInvitation withStatus(InvitationStatus newStatus) => CompanyInvitation(
    id: id,
    email: email,
    role: role,
    name: name,
    createdAt: createdAt,
    expiresAt: expiresAt,
    status: newStatus,
  );
}
