import 'package:flutter/material.dart';

import '../../iam/domain/user.dart';
import '../../fleet/presentation/fleet_screen.dart';
import '../../routes/app_routes.dart';
import '../../routes/presentation/routes_screen.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/rutana_app_bar.dart';
import '../../shared/widgets/rutana_logo.dart';

class MenuOption {
  final String title;
  final IconData icon;
  const MenuOption(this.title, this.icon);
}

const List<MenuOption> menuOptions = [
  MenuOption('Home', Icons.home_outlined),
  MenuOption('Routes', Icons.route_outlined),
  MenuOption('Vehicles and teams', Icons.local_shipping_outlined),
  MenuOption('Clients', Icons.business_outlined),
  MenuOption('User management', Icons.group_outlined),
  MenuOption('Incidents', Icons.warning_amber_outlined),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selected = 0;

  void _signOut() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ModalRoute.of(context)?.settings.arguments as User?;
    final option = menuOptions[_selected];

    return Scaffold(
      appBar: RutanaAppBar(
        title: option.title,
        onProfileTap: () =>
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Coming soon'))),
      ),
      drawer: _buildDrawer(user),
      body: _selected == 0
          ? _buildDashboard(user)
          : _selected == 1
          ? RoutesScreen(user: user)
          : _selected == 2
          ? FleetScreen(user: user)
          : _buildComingSoon(option),
    );
  }

  Widget _buildDrawer(User? user) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.navyDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const RutanaLogo(size: 40),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          for (var i = 0; i < menuOptions.length; i++)
            ListTile(
              leading: Icon(menuOptions[i].icon),
              title: Text(menuOptions[i].title),
              selected: i == _selected,
              selectedColor: AppColors.navy,
              selectedTileColor: AppColors.navy.withValues(alpha: 0.08),
              onTap: () {
                setState(() => _selected = i);
                Navigator.pop(context);
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(User? user) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${user?.fullName ?? ''}',
                      style: const TextStyle(
                        fontSize: 22,
                        color: AppColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (user != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.role,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'What do you want to manage today?',
                      style: TextStyle(color: AppColors.gray),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 148,
            ),
            itemCount: menuOptions.length - 1,
            itemBuilder: (context, index) {
              final i = index + 1;
              final item = menuOptions[i];
              return Card(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _selected = i),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(item.icon, size: 32, color: AppColors.navy),
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComingSoon(MenuOption option) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(option.icon, size: 64, color: AppColors.gray),
          const SizedBox(height: 16),
          const Text('Coming soon', style: TextStyle(fontSize: 22)),
        ],
      ),
    );
  }
}
