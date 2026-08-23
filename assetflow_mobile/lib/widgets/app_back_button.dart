import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A back button that always works, regardless of how the screen
/// was reached.
///
/// Screens reached via context.push() (drilling in from another
/// screen) have something to pop -- Navigator.canPop() is true,
/// and this behaves like a normal back arrow.
///
/// Screens reached via context.go() (the bottom-nav tabs --
/// Reports, Profile/Settings) have nothing to pop, since go()
/// replaces the current location rather than stacking on top of
/// it. For those, this falls back to going straight to the
/// dashboard instead of leaving the person with no way back at
/// all -- every child page gets a working, visible back button,
/// no exceptions, regardless of entry path.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      },
    );
  }
}
