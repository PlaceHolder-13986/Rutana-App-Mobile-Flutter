import 'package:flutter/material.dart';

import '../../../iam/domain/user.dart';
import '../../../shared/theme/app_colors.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip.dart';

class NewRouteModal extends StatefulWidget {
  final User user;
  const NewRouteModal({super.key, required this.user});

  static Future<Trip?> show(BuildContext context, User user) {
    return showDialog<Trip>(
      context: context,
      builder: (context) => NewRouteModal(user: user),
    );
  }

  @override
  State<NewRouteModal> createState() => _NewRouteModalState();
}

class _NewRouteModalState extends State<NewRouteModal> {
  final _nameController = TextEditingController(text: 'Ruta de Distribución');
  String _selectedType = 'Reparto';
  Color _selectedColor = AppColors.navy;
  String? _error;

  final List<String> _routeTypes = [
    'Reparto',
    'Express',
    'Traslado',
    'Logística Inversa',
  ];

  final List<Color> _colorOptions = [
    AppColors.navy,
    const Color(0xFFFF5722),
    const Color(0xFF1B7F3B),
    const Color(0xFF7B1FA2),
    const Color(0xFF0288D1),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ingrese un nombre para la ruta');
      return;
    }

    try {
      final trip = TripRepository.instance.create(widget.user);
      trip.name = name;
      trip.origin = 'Almacén Principal';
      trip.departure = DateTime.now().add(const Duration(hours: 4));
      trip.routeType = _selectedType;
      trip.colorHex = '#${_selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      
      TripRepository.instance.save(widget.user, trip);
      Navigator.pop(context, trip);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'New route',
        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyDark),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la ruta',
                  hintText: 'Ej. Ate - Callao - Ventanilla',
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de ruta',
                ),
                items: _routeTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 16),
              const Text(
                'Color identificador',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navyDark),
              ),
              const SizedBox(height: 8),
              Row(
                children: _colorOptions.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black87, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.yellow,
            foregroundColor: AppColors.navyDark,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
