import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Bottom-tab shell for the customer experience.
///
/// Three destinations, because that is how many distinct jobs a customer has:
/// find a tailor, look at their appointments, and manage their account.
///
/// Design guideline — Searching > Best practices: "If search is important,
/// consider making it a primary action." Search lives inside Discover rather
/// than as its own tab, because on this app searching is a way of filtering the
/// nearby list — not a separate destination.
class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          // No hairline on the dark appearance: the bar sits on the same
          // near-black ground as the content, and Monochrome & Gold separates
          // dark planes by surface value, never by borders. Light keeps the
          // rule because white-on-off-white has no value separation to lean
          // on — the same split the card theme and PrimaryCtaBar make.
          border: colors.brightness == Brightness.dark
              ? null
              : Border(
                  top: BorderSide(
                    color: colors.separator,
                    width: AppSizing.separator,
                  ),
                ),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (index) => shell.goBranch(
            index,
            // Tapping the current tab returns it to its root, which is the
            // behaviour people expect from a tab bar.
            initialLocation: index == shell.currentIndex,
          ),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
