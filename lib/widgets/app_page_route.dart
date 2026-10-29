import 'package:flutter/material.dart';

/// PlantPal's page transition, used for every in-app navigation:
/// a short fade plus a small upward slide, 300ms in, 250ms back.
/// Small enough not to feel slow, big enough to feel like moving
/// to a new room rather than a hard cut. The default Material
/// slide from the right felt like a generic Android app; this
/// keeps the pixel-pet feel consistent on Android and web.
///
/// Hero animations (the pet growing from shelf to plant screen)
/// run on top of this route — Hero needs a PageRoute, not a
/// theme-level transition, which is why this is a route helper
/// rather than a pageTransitionsTheme entry.
Route<T> slideFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
