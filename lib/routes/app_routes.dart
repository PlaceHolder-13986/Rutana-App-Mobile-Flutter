import 'package:flutter/material.dart';

import '../home/presentation/home_screen.dart';
import '../iam/presentation/login_screen.dart';
import '../iam/presentation/register_screen.dart';

class AppRoutes {
  static const String login = '/';
  static const String register = '/register';
  static const String home = '/home';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    home: (context) => const HomeScreen(),
  };
}
