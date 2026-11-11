import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'shared/theme/app_theme.dart';

void main() {
  runApp(const RutanaApp());
}

class RutanaApp extends StatelessWidget {
  const RutanaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rutana',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,

      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}
