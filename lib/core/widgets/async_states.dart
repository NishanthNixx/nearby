import 'package:flutter/material.dart';

import '../errors/app_failure.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'illustrations.dart';

/// Shown while a screen has nothing to display yet and no skeleton fits.
///
/// Prefer a skeleton where the shape of the result is known — it reads as
/// "almost there" rather than "waiting". This is the fallback for cases where
/// the shape is not knowable.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  /// Optional context, e.g. "Finding tailors near you". Worth including when
  /// the wait might be more than a moment, so the delay feels purposeful.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label ?? 'Loading',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.colors.primary,
                ),
              ),
              if (label != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: context.type.subhead.copyWith(
                    color: context.colors.labelSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when a request succeeded but produced nothing.
///
/// An empty state is distinct from an error: nothing went wrong, there is just
/// nothing here. It says so, and offers the most useful next step.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.illustration,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  /// Preferred over [icon] where one fits the situation. A drawn illustration
  /// is what makes an empty state read as designed rather than unfinished.
  final NearbyIllustration? illustration;

  /// Fallback when no illustration suits.
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A drawn illustration where one fits the situation; otherwise a
            // glyph. Either way it is decorative — the title and message carry
            // the meaning, so it stays out of the accessibility tree rather
            // than being announced as a redundant label.
            if (illustration != null)
              Illustration(kind: illustration!)
            else
              ExcludeSemantics(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.bgGrouped,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: AppSizing.iconXl,
                    color: colors.labelSecondary,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.type.title3.copyWith(color: colors.label),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.type.subhead.copyWith(
                color: colors.labelSecondary,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
            if (onSecondaryAction != null && secondaryActionLabel != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when something failed.
///
/// Design guideline — Feedback > Best practices: "Show people when a command
/// can't be carried out and help them understand why."
///
/// Takes an [AppFailure] rather than a raw error, so the title, explanation and
/// recovery label all come from the failure itself. A raw platform exception
/// can never reach this widget.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.failure,
    this.onRetry,
    this.compact = false,
  });

  final AppFailure failure;

  /// Wired to the failure's own recovery label where it has one.
  final VoidCallback? onRetry;

  /// A tighter layout for use inside a card or a list section.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (!compact) Illustration(kind: _illustrationFor(failure)),
        if (!compact) const SizedBox(height: AppSpacing.lg),
        Text(
          failure.title,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: (compact ? context.type.headline : context.type.title3)
              .copyWith(color: colors.label),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          failure.message,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: context.type.subhead.copyWith(color: colors.labelSecondary),
        ),
        if (onRetry != null) ...[
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
          FilledButton(
            onPressed: onRetry,
            child: Text(failure.recovery ?? 'Try again'),
          ),
        ],
      ],
    );

    // liveRegion so an assistive technology announces the failure when it
    // replaces the loading state, rather than leaving the user waiting.
    return Semantics(
      liveRegion: true,
      child: compact
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: content,
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.xxxl,
                ),
                child: content,
              ),
            ),
    );
  }

  /// Picks the drawing that matches what actually went wrong, so the
  /// illustration carries information rather than just filling space.
  static NearbyIllustration _illustrationFor(AppFailure failure) =>
      switch (failure) {
        LocationFailure() => NearbyIllustration.locationOff,
        SlotUnavailableFailure() => NearbyIllustration.noAvailability,
        NotFoundFailure() => NearbyIllustration.noSearchResults,
        _ => NearbyIllustration.problem,
      };
}

/// Renders the four states of an [AsyncSnapshot]-like value so a screen never
/// shows a blank body.
///
/// Design guideline — Loading: content should appear as soon as possible, and
/// a screen with nothing on it reads as broken.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.isLoading,
    required this.failure,
    required this.data,
    required this.builder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.onRetry,
    this.isEmpty,
  });

  final bool isLoading;
  final AppFailure? failure;
  final T? data;

  final Widget Function(BuildContext context, T data) builder;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final VoidCallback? onRetry;

  /// Decides whether non-null [data] counts as empty. Without it, an empty
  /// list would render as a bare white screen.
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    final currentFailure = failure;
    if (currentFailure != null) {
      return ErrorView(failure: currentFailure, onRetry: onRetry);
    }

    final currentData = data;

    // Data already in hand wins over a refresh in flight: replacing a populated
    // list with a spinner on every pull-to-refresh is worse than leaving the
    // content up.
    if (currentData != null) {
      final empty = isEmpty?.call(currentData) ?? false;
      if (empty && emptyBuilder != null) return emptyBuilder!(context);
      return builder(context, currentData);
    }

    if (isLoading) {
      return loadingBuilder?.call(context) ?? const LoadingView();
    }

    return emptyBuilder?.call(context) ?? const SizedBox.shrink();
  }
}
