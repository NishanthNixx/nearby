import 'package:flutter/material.dart';

import '../errors/app_failure.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Transient confirmations and failure notices.
///
/// Design guideline — Feedback > Best practices: "When it makes sense, confirm
/// that a significant action or task has completed... It's generally best to
/// reserve this type of confirmation for activities that are sufficiently
/// important." And: "Use alerts to deliver critical — and ideally actionable —
/// information. By design, alerts disrupt the current context."
///
/// So: a snack bar for "done" and for recoverable problems, and a dialog only
/// where the user must decide something.
abstract final class AppFeedback {
  /// Confirms something worth confirming — a booking made, a profile saved.
  static void showSuccess(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: context.colors.open,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Reports a failure without taking over the screen.
  ///
  /// Takes an [AppFailure] so the wording is the failure's own — a raw
  /// exception string never reaches the user.
  static void showFailure(
    BuildContext context, {
    required AppFailure failure,
    VoidCallback? onRetry,
  }) {
    _show(
      context,
      message: failure.message,
      icon: Icons.error_rounded,
      iconColor: context.colors.error,
      actionLabel: onRetry == null ? null : (failure.recovery ?? 'Try again'),
      onAction: onRetry,
      duration: const Duration(seconds: 6),
    );
  }

  static void showInfo(BuildContext context, {required String message}) {
    _show(
      context,
      message: message,
      icon: Icons.info_rounded,
      iconColor: context.colors.primary,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // Only one at a time. Stacked snack bars queue up and outlive the context
    // that produced them.
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        content: Row(
          children: [
            Icon(icon, size: AppSizing.iconMd, color: iconColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
  }

  /// Asks the user to confirm something they cannot undo.
  ///
  /// Design guideline — Feedback > Best practices: "Warn people when they
  /// initiate a task that can cause data loss that's unexpected and
  /// irreversible."
  ///
  /// Returns true only on an explicit confirm — dismissing counts as "no".
  static Future<bool> confirmDestructive(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Keep it',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          actions: [
            // The non-destructive choice sits where the thumb rests and is the
            // visually quieter of the two.
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.brightness == Brightness.light
                    ? Colors.white
                    : const Color(0xFF3A0906),
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

/// A one-line inline notice, for a form-level problem that belongs beside the
/// fields rather than in a transient snack bar.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.tone = NoticeTone.error,
    this.icon,
  });

  final String message;
  final NoticeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (color, defaultIcon) = switch (tone) {
      NoticeTone.error => (colors.error, Icons.error_outline_rounded),
      NoticeTone.warning => (colors.warning, Icons.warning_amber_rounded),
      NoticeTone.info => (colors.primary, Icons.info_outline_rounded),
      NoticeTone.success => (colors.open, Icons.check_circle_outline_rounded),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          // A raised surface rather than a tinted wash behind a hairline. The
          // glyph carries the tone; on a dark ground a 10%-alpha wash of white
          // under a 32%-alpha white border was the last bordered panel on
          // otherwise borderless screens.
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: colors.brightness == Brightness.dark
              ? null
              : Border.all(color: colors.separator),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? defaultIcon, size: AppSizing.iconMd, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: context.type.footnote.copyWith(color: colors.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum NoticeTone { error, warning, info, success }
