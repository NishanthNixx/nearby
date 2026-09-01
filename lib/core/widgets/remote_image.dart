import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A network image with all four of its states handled.
///
/// Design guideline — Loading: show something immediately rather than a blank
/// box, and Images: make sure images look right in both appearances.
///
/// Falls back to a neutral glyph on failure or when there is no URL at all, so
/// a listing without a photo still looks intentional instead of broken.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = AppRadius.md,
    this.fallbackIcon = Icons.storefront_rounded,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.fallback,
  });

  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final IconData fallbackIcon;
  final BoxFit fit;
  final String? semanticLabel;

  /// Shown instead of [fallbackIcon] when there is no URL or the load fails.
  ///
  /// A business passes its generated identity here, so an unreachable photo
  /// looks exactly like a shop that has not uploaded one — which is the honest
  /// result, and far better than a generic grey glyph that reads as broken.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final resolved = url?.trim();

    // The in-memory backend hands out `memory://` placeholders; treat them as
    // "no image" rather than letting the loader fail on them.
    final isLoadable =
        resolved != null &&
        resolved.isNotEmpty &&
        (resolved.startsWith('http://') || resolved.startsWith('https://'));

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: isLoadable
            ? Image.network(
                resolved,
                fit: fit,
                width: width,
                height: height,
                semanticLabel: semanticLabel,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  // While loading, show the fallback rather than an empty box:
                  // for a business that means its identity is on screen from
                  // the first frame and the photo fades in over it.
                  if (fallback != null) return fallback!;
                  return _Placeholder(
                    icon: fallbackIcon,
                    showProgress: true,
                    progress: progress.expectedTotalBytes == null
                        ? null
                        : progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!,
                  );
                },
                errorBuilder: (context, error, stack) =>
                    fallback ?? _Placeholder(icon: fallbackIcon),
                // A short fade stops images from snapping in as they decode.
                frameBuilder: (context, child, frame, wasSyncLoaded) {
                  if (wasSyncLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: AppMotion.normal,
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
              )
            : (fallback ?? _Placeholder(icon: fallbackIcon)),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    this.showProgress = false,
    this.progress,
  });

  final IconData icon;
  final bool showProgress;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ColoredBox(
      color: colors.bgGrouped,
      child: Center(
        child: showProgress
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress,
                  color: colors.labelTertiary,
                ),
              )
            : Icon(icon, color: colors.labelTertiary, size: AppSizing.iconLg),
      ),
    );
  }
}

/// A circular avatar that falls back to initials.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.size = 40,
  });

  final String initials;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = photoUrl?.trim();

    if (url != null && url.startsWith('http')) {
      return RemoteImage(
        url: url,
        width: size,
        height: size,
        radius: size / 2,
        fallbackIcon: Icons.person_rounded,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
