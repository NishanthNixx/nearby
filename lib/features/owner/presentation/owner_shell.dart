import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// Bottom-tab shell for the tailor's side of the app.
///
/// Four destinations named in the tailor's own words — Appointments, Services,
/// Hours, Shop — rather than product jargon. The audience is a local tailor with
/// limited technical experience, so every label is a thing they already think
/// about.
///
/// Appointments is first and default, because that is the job the app exists to
/// do for them.
class OwnerShell extends StatelessWidget {
  const OwnerShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: shell,
      // The bar sits directly on the near-black ground with no hand-drawn top
      // hairline — in this scheme dark surfaces are separated by value, never
      // by borders, and the themed NavigationBar already carries the right
      // fill and selection treatment.
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.design_services_outlined),
            selectedIcon: Icon(Icons.design_services_rounded),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule_rounded),
            label: 'Hours',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Shop',
          ),
        ],
      ),
    );
  }
}
