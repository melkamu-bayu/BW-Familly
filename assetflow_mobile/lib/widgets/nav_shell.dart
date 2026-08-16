import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/dashboard/dashboard_screen.dart';
import '../screens/vehicles/vehicles_list_screen.dart';
import '../screens/transactions/add_transaction_sheet.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../state/auth_provider.dart';

/// Top-level shell holding the bottom nav. Section 25 lists 11 nav items;
/// only Dashboard, Vehicles, Alerts, and Settings get bottom-nav slots here
/// since 11 items don't fit a bottom bar -- the rest (Houses, Construction
/// Shop, Gold Project, Accounts, Reports, Analytics) are reachable from
/// Settings until they get dedicated entry points.
class NavShell extends ConsumerStatefulWidget {
  final Widget child;
  const NavShell({super.key, required this.child});

  @override
  ConsumerState<NavShell> createState() => _NavShellState();
}

class _NavShellState extends ConsumerState<NavShell> {
  int _currentIndex = 0;

  static const _tabs = ['/dashboard', '/vehicles', '/notifications', '/settings'];

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    context.go(_tabs[index]);
  }

  Future<void> _showAddTransactionMenu(BuildContext context) async {
    final kind = await showModalBottomSheet<TransactionKind>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Colors.green),
              title: const Text('Add Revenue'),
              onTap: () => Navigator.pop(context, TransactionKind.revenue),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.red),
              title: const Text('Add Expense'),
              onTap: () => Navigator.pop(context, TransactionKind.expense),
            ),
          ],
        ),
      ),
    );

    if (kind != null && context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => AddTransactionSheet(kind: kind),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final canRecord = authState.canRecordTransactions;

    return Scaffold(
      body: widget.child,
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              onPressed: () => _showAddTransactionMenu(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Transaction'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'Vehicles'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
