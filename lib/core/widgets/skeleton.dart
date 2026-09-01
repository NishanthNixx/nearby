import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A placeholder block shaped like the content that will replace it.
///
/// Design guideline — Loading > Best practices: "Show something as soon as
/// possible. If you make people wait for loading to complete before displaying
/// anything, they can interpret the lack of content as a problem with your app.
/// Instead, consider showing placeholder text, graphics, or animations as
/// content loads."
///
/// Skeletons are shaped like the real thing, so the layout does not jump when
/// content arrives.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.xs,
  });

  /// A skeleton sized for one line of text at [style]'s size.
  factory Skeleton.text({Key? key, double? width, double fontSize = 17}) =>
      Skeleton(
        key: key,
        width: width,
        height: fontSize * 0.8,
        radius: AppRadius.xs,
      );

  /// A square skeleton for an avatar or thumbnail.
  factory Skeleton.square(double size, {Key? key, double? radius}) => Skeleton(
    key: key,
    width: size,
    height: size,
    radius: radius ?? AppRadius.md,
  );

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _SkeletonShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.colors.skeleton,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A slow, low-contrast pulse over its child.
///
/// Design guideline — Motion > Best practices: "Make motion optional. Not
/// everyone can or wants to experience the motion in your app." When the
/// platform's reduce-motion setting is on, the pulse is skipped entirely and
/// the placeholder simply sits still — it still communicates "loading" through
/// shape alone.
class _SkeletonShimmer extends StatefulWidget {
  const _SkeletonShimmer({required this.child});

  final Widget child;

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1100),
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      _controller.stop();
      return widget.child;
    }

    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }

    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// A skeleton shaped like a discovery card, used while the nearby list loads.
class BusinessCardSkeleton extends StatelessWidget {
  const BusinessCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // Matches NearbyCard: borderless in dark, hairline in light. A skeleton
        // that is shaped differently from the card replacing it makes the
        // layout jump on load.
        border: context.colors.brightness == Brightness.dark
            ? null
            : Border.all(color: context.colors.separator),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton.square(AppSizing.thumbnail),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton.text(width: 160, fontSize: 17),
                const SizedBox(height: AppSpacing.sm),
                Skeleton.text(width: 110, fontSize: 15),
                const SizedBox(height: AppSpacing.md),
                const Row(
                  children: [
                    Skeleton(width: 64, height: 22, radius: AppRadius.xs),
                    SizedBox(width: AppSpacing.sm),
                    Skeleton(width: 78, height: 22, radius: AppRadius.xs),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
