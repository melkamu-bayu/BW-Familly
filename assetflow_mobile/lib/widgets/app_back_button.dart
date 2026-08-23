import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AssetFlow hierarchical back button.
///
/// Navigation hierarchy:
///
/// Dashboard
///   └── Assets
///        ├── Vehicles
///        │    └── Vehicle Detail
///        ├── Properties
///        │    └── Property Detail
///        ├── Shop
///        └── Gold Project
///
/// Expected behavior:
///   Assets -> Dashboard
///   Vehicles -> Assets
///   Vehicle Detail -> Vehicles
///   Properties -> Assets
///   Property Detail -> Properties
///   Shop -> Assets
///   Gold Project -> Assets
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  String _parentRoute(String path) {
    // Asset child pages -> Assets.
    if (path == '/vehicles' ||
        path == '/properties' ||
        path == '/shop' ||
        path == '/gold-project') {
      return '/assets';
    }

    // Asset detail pages -> their immediate list parent.
    if (path.startsWith('/vehicles/')) {
      return '/vehicles';
    }

    if (path.startsWith('/properties/')) {
      return '/properties';
    }

    // Assets itself -> Dashboard/Home.
    if (path == '/assets') {
      return '/dashboard';
    }

    // Other top-level pages -> Dashboard/Home.
    if (path == '/notifications' ||
        path == '/settings' ||
        path == '/accounts' ||
        path == '/reports') {
      return '/dashboard';
    }

    return '/dashboard';
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () {
        final router = GoRouter.of(context);
        final currentPath = router.state.uri.path;

        // If this page was opened with context.push(),
        // pop exactly one level.
        //
        // Example:
        // Vehicles -> Vehicle Detail -> Vehicles
        // Properties -> Property Detail -> Properties
        if (Navigator.of(context).canPop()) {
          context.pop();
          return;
        }

        // If the page was opened with context.go(), there is
        // no navigation stack to pop. Explicitly navigate to
        // the correct immediate parent.
        final parent = _parentRoute(currentPath);

        if (parent != currentPath) {
          context.go(parent);
        }
      },
    );
  }
}
