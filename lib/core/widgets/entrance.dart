import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Fades and lifts a list item into place, staggered by its position.
///
/// Design guideline — Motion > Best practices: "Aim for brevity and precision
/// in feedback animations. When animated feedback is brief and precise, it tends
/// to feel lightweight and unobtrusive." So this is 280ms, a 12pt rise, and it
/// plays once — not a performance, just enough that a list of results arrives
/// rather than appearing.
///
/// Design guideline — Motion: "Make motion optional." When the platform's
/// reduce-motion setting is on, the child is returned untouched.
///
/// The stagger is implemented with per-item [Interval] curves on each item's own
/// controller rather than with delayed timers, so nothing is left pending if the
/// list is disposed mid-animation.
class EntranceTransition extends StatefulWidget {
  const EntranceTransition({
    super.key,
    required this.index,
    required this.child,
    this.stagger = const Duration(milliseconds: 55),
    this.maxStaggeredItems = 6,
  });

  final int index;
  final Widget child;

  /// Delay added per item.
  final Duration stagger;

  /// Items past this position appear immediately. Staggering a long list means
  /// the last item waits seconds for no benefit, and someone scrolling fast
  /// would watch content trickle in.
  final int maxStaggeredItems;

  @override
  State<EntranceTransition> createState() => _EntranceTransitionState();
}

class _EntranceTransitionState extends State<EntranceTransition>
    with SingleTickerProviderStateMixin {
  static const Duration _travel = Duration(milliseconds: 280);

  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    final steps = widget.index.clamp(0, widget.maxStaggeredItems);
    final delay = widget.stagger * steps;
    final total = delay + _travel;

    _controller = AnimationController(duration: total, vsync: this);

    // The delay lives in the curve's interval rather than in a Timer, so there
    // is nothing to cancel and nothing left pending on dispose.
    final delayFraction = total.inMilliseconds == 0
        ? 0.0
        : delay.inMilliseconds / total.inMilliseconds;

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delayFraction, 1, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        return Opacity(
          opacity: t,
          // Rises rather than slides sideways: the list is vertical, so the
          // motion follows the direction the content actually arrives from.
          child: Transform.translate(
            offset: Offset(0, (1 - t) * AppSpacing.md),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
