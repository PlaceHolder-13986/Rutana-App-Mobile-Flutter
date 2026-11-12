import 'package:rutana_app_movil/iam/domain/user.dart';
import 'package:rutana_app_movil/fleet/data/fleet_repository.dart';

User testUser(String company, {String role = 'Administrator'}) => User(
  fullName: 'Testing',
  email: 'testing@demo.pe',
  phone: '',
  company: company,
  ruc: company,
  password: '',
  role: role,
);

Vehicle saveTestVehicle(
  FleetRepository repo,
  User user, {
  String? id,
  String plate = 'TST-123',
  double capacity = 3000,
  VehicleStatus status = VehicleStatus.enabled,
}) => repo.saveVehicle(
  user,
  id: id,
  plate: plate,
  type: 'Camión',
  brand: 'Volvo',
  model: 'FH',
  capacity: capacity,
  status: status,
);
