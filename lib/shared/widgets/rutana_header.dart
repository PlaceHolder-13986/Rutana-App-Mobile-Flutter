import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'rutana_logo.dart';

class RutanaHeader extends StatelessWidget {
  const RutanaHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navyDark,
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              RutanaLogo(),
              SizedBox(height: 8),
              Text('Rutana', style: TextStyle(color: Colors.white, fontSize: 28)),
              SizedBox(height: 8),
              Text(
                'The best platform for carriers and logistics in Peru',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
