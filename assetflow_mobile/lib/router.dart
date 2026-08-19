import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/models.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/assets/assets_hub_screen.dart';
import 'screens/vehicles/vehicles_list_screen.dart';
import 'screens/vehicles/vehicle_detail_screen.dart';
import 'screens/properties/properties_list_screen.dart';
import 'screens/properties/property_detail_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'screens/projects/gold_project_screen.dart';
import 'screens/accounts/accounts_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'state/auth_provider.dart';
import 'widgets/nav_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggingIn = state.matchedLocation == '/login';

      if (authState.status == AuthStatus.unknown) return null; // splash still resolving
      if (authState.status == AuthStatus.unauthenticated && !isLoggingIn) return '/login';
      if (authState.status == AuthStatus.authenticated && isLoggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => NavShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/assets', builder: (context, state) => const AssetsHubScreen()),
          GoRoute(path: '/vehicles', builder: (context, state) => const VehiclesListScreen()),
          GoRoute(
            path: '/vehicles/:id',
            builder: (context, state) => VehicleDetailScreen(
              vehicleId: state.pathParameters['id']!,
              vehicle: state.extra as Vehicle?,
            ),
          ),
          GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/properties', builder: (context, state) => const PropertiesListScreen()),
          GoRoute(
            path: '/properties/:id',
            builder: (context, state) => PropertyDetailScreen(
              propertyId: state.pathParameters['id']!,
              property: state.extra as Property?,
            ),
          ),
          GoRoute(path: '/shop', builder: (context, state) => const ShopScreen()),
          GoRoute(path: '/gold-project', builder: (context, state) => const GoldProjectScreen()),
          GoRoute(path: '/accounts', builder: (context, state) => const AccountsScreen()),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod's authProvider changes into something GoRouter's
/// refreshListenable (a plain Listenable) can react to, so a login/logout
/// immediately re-runs the redirect logic above.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
