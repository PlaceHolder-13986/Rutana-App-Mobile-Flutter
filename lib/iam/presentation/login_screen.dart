import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/rutana_header.dart';
import '../data/user_repository.dart';

/// StatefulWidget: la pantalla cambia (texto escrito, errores, ver contraseña).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _repository = UserRepository();

  // Controladores: guardan lo que el usuario escribe en cada campo
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Estado de la pantalla (equivale a los mutableStateOf de Kotlin)
  bool _showPassword = false;
  bool _loading = false;
  String _error = '';
  String _message = '';

  @override
  void dispose() {
    // Siempre liberar los controladores al cerrar la pantalla
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    if (email.trim().isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final user = await _repository.signIn(email, password);

    if (!mounted) return; // la pantalla pudo cerrarse mientras se esperaba
    setState(() => _loading = false);

    if (user != null) {
      // 👉 pushReplacementNamed: va al Home y QUITA el login de la pila
      //    (el botón "atrás" no regresa al login). Se envía el usuario como argumento.
      Navigator.pushReplacementNamed(context, AppRoutes.home, arguments: user);
    } else {
      setState(() => _error = 'Incorrect email or password');
    }
  }

  Future<void> _goToRegister() async {
    // 👉 pushNamed + await: espera a que Register se cierre y recibe el email registrado
    final registeredEmail = await Navigator.pushNamed(context, AppRoutes.register);

    if (registeredEmail is String && mounted) {
      setState(() {
        _emailController.text = registeredEmail;
        _passwordController.clear();
        _error = '';
        _message = 'Account created. Log in to continue.';
      });
    }
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
                    'Log In',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, color: AppColors.navyDark),
                  ),
                  const SizedBox(height: 16),

                  if (_message.isNotEmpty) ...[
                    Text(_message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.success)),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'ejemplo@empresa.com',
                    ),
                    onChanged: (_) => setState(() {
                      _error = '';
                      _message = '';
                    }),
                  ),
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
                    onSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 16),

                  if (_error.isNotEmpty) ...[
                    Text(_error, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                  ],

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.navyDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _loading
                          ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Log in'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _goToRegister,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navyDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Create an account'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon')),
                    ),
                    child: const Text('Forgot your password?',
                        style: TextStyle(color: AppColors.navyDark)),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'Demo user: admin@rutana.com / 123456',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.gray),
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
