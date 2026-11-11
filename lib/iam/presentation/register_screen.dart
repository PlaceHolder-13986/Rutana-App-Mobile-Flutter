import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/rutana_header.dart';
import '../data/user_repository.dart';
import '../domain/user.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _repository = UserRepository();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _rucController = TextEditingController();
  final _passwordController = TextEditingController();

  String _role = '';          // 'Administrator' o 'Driver'
  bool _acceptTerms = false;
  bool _showPassword = false;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _rucController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  String? _validate() {
    final email = _emailController.text.trim();
    if (_role.isEmpty) return 'Select Administrator or Driver';
    if (_nameController.text.trim().isEmpty ||
        email.isEmpty ||
        _phoneController.text.isEmpty ||
        _companyController.text.trim().isEmpty ||
        _rucController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      return 'Complete all the fields';
    }
    if (!email.contains('@') || !email.contains('.')) return 'Enter a valid email';
    if (_phoneController.text.length != 9) return 'The phone must have 9 digits';
    if (_rucController.text.length != 11) return 'The RUC must have 11 digits';
    if (_passwordController.text.length < 6) return 'The password must have at least 6 characters';
    if (!_acceptTerms) return 'You must accept the terms and conditions';
    return null;
  }

  Future<void> _register() async {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() => _loading = true);

    final email = _emailController.text.trim().toLowerCase();
    final saved = await _repository.register(User(
      fullName: _nameController.text.trim(),
      email: email,
      phone: _phoneController.text,
      company: _companyController.text.trim(),
      ruc: _rucController.text,
      password: _passwordController.text,
      role: _role,
    ));

    if (!mounted) return;
    setState(() => _loading = false);

    if (saved) {

      Navigator.pop(context, email);
    } else {
      setState(() => _error = 'This email is already registered');
    }
  }

  void _showTerms() {

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms and conditions'),
        content: const SingleChildScrollView(

          child: Text(
            'By creating an account in Rutana you agree to use the application only '
                'for the planning and management of delivery routes of your company.\n\n'
                'You are responsible for keeping your password safe and for the information '
                'you register about vehicles, clients and routes.\n\n'
                'Rutana stores your data to provide the service and does not share it with '
                'third parties without your consent.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(
            onPressed: () {
              setState(() {
                _acceptTerms = true;
                _error = '';
              });
              Navigator.pop(context);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Widget _field(
      TextEditingController controller,
      String label,
      String hint, {
        TextInputType keyboard = TextInputType.text,
        int? maxDigits,
      }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,

      inputFormatters: maxDigits == null
          ? null
          : [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(maxDigits)],
      decoration: InputDecoration(labelText: label, hintText: hint),
      onChanged: (_) => setState(() => _error = ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const RutanaHeader(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, color: AppColors.navyDark),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          title: 'Administrator',
                          icon: Icons.badge_outlined,
                          selected: _role == 'Administrator',
                          onTap: () => setState(() {
                            _role = 'Administrator';
                            _error = '';
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoleCard(
                          title: 'Driver',
                          icon: Icons.directions_car_outlined,
                          selected: _role == 'Driver',
                          onTap: () => setState(() {
                            _role = 'Driver';
                            _error = '';
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _field(_nameController, 'Full Name', 'Juan Pérez'),
                  const SizedBox(height: 16),
                  _field(_emailController, 'Email', 'ejemplo@empresa.com',
                      keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _field(_phoneController, 'Phone', '999 999 999',
                            keyboard: TextInputType.phone, maxDigits: 9),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_companyController, 'Company', 'Empresa S.A.C.')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _field(_rucController, 'RUC', '20123456789',
                      keyboard: TextInputType.number, maxDigits: 11),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    onChanged: (_) => setState(() => _error = ''),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Checkbox(
                        value: _acceptTerms,
                        onChanged: (value) => setState(() {
                          _acceptTerms = value ?? false;
                          _error = '';
                        }),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _showTerms,
                          style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                          child: const Text('I agree to the terms and conditions',
                              style: TextStyle(color: AppColors.navyDark)),
                        ),
                      ),
                    ],
                  ),

                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_error, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.navyDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Create account'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navyDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Already have an account? Log in'),
                    ),
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

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 110,
        decoration: BoxDecoration(

          color: selected ? const Color(0xFFFFF7CC) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.navyDark : AppColors.gray,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.navyDark),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: AppColors.navyDark, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
