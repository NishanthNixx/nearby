import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/remote_image.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';

/// The customer's account.
///
/// Deliberately short. There is no appearance setting here.
///
/// Design guideline — Dark Mode > Best practices: "Avoid offering an app-specific
/// appearance setting." Nearby follows the platform, so there is nothing to
/// configure.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppFeedback.confirmDestructive(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to see your bookings.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay signed in',
    );

    if (!confirmed) return;
    await ref.read(authControllerProvider.notifier).signOut();
    // The router's redirect handles navigation.
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final controller = TextEditingController(text: user.displayName ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditNameSheet(controller: controller),
    );

    if (saved != true) return;

    try {
      await ref
          .read(authRepositoryProvider)
          .updateProfile(displayName: controller.text);
      if (context.mounted) {
        AppFeedback.showSuccess(context, message: 'Name updated.');
      }
    } catch (error) {
      if (context.mounted) {
        AppFeedback.showFailure(context, failure: toAppFailure(error));
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      // bgBase, not bgGrouped: in Monochrome & Gold the near-black ground is
      // the one plane and the borderless cards separate by surface value
      // alone (the two are the same colour in dark; this keeps light honest).
      backgroundColor: colors.bgBase,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.lg,
                AppSpacing.screenMargin,
                0,
              ),
              child: Text(
                'Account',
                style: context.type.largeTitle.copyWith(color: colors.label),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
              ),
              child: NearbyCard(
                child: Row(
                  children: [
                    InitialsAvatar(
                      initials: user.initials,
                      photoUrl: user.photoUrl,
                      size: AppSizing.avatarLarge * 0.62,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: context.type.title3.copyWith(
                              color: colors.label,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            user.email,
                            style: context.type.subhead.copyWith(
                              color: colors.labelSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SectionHeader(title: 'Your details'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
              ),
              child: NearbyCardList(
                children: [
                  _SettingRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Name',
                    value: user.name,
                    onTap: () => _editName(context, ref),
                  ),
                  _SettingRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: user.email,
                  ),
                  _SettingRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: user.phone ?? 'Not set',
                    tabularValue: user.phone != null,
                  ),
                  _SettingRow(
                    icon: Icons.event_note_outlined,
                    label: 'Member since',
                    value: Fmt.dayMonthYear(user.createdAt),
                    tabularValue: true,
                  ),
                ],
              ),
            ),

            const SectionHeader(title: 'About'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
              ),
              child: NearbyCardList(
                children: [
                  const _SettingRow(
                    icon: Icons.brightness_6_outlined,
                    label: 'Appearance',
                    value: 'Follows your device setting',
                  ),
                  _SettingRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Version',
                    value: AppConfig.dataSource == DataSource.inMemory
                        ? '0.1.0 · sample data'
                        : '0.1.0',
                    tabularValue: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
              ),
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context, ref),
                icon: const Icon(Icons.logout_rounded, size: AppSizing.iconMd),
                label: const Text('Sign out'),
                // The one destructive action on the screen, so it is the one
                // outline that leaves the neutral palette: label and hairline
                // both in the error tone. The shape stays the theme's stadium —
                // a pill, like every other button in the app.
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error, width: 1.5),
                  minimumSize: const Size(
                    double.infinity,
                    AppSizing.secondaryButtonHeight,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

/// One fact about the account, as a micro-label over its value.
///
/// The value is the content and the label is the annotation, so the value gets
/// the white body weight and the label the tiny letterspaced caption the rest
/// of the app uses for group headings.
///
/// Stacked rather than label-left/value-right: side by side, a long value at
/// the 2x text ceiling has to be truncated to a couple of glyphs, and none of
/// these values appear anywhere else on the screen. Stacked, every line gets
/// the full card width at every text size.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.tabularValue = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  /// Set for values made of figures — a date, a phone number, a version — so
  /// the digits sit on a fixed pitch down the column.
  final bool tabularValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSizing.iconMd, color: colors.labelSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Uppercases for display and keeps the natural-case string for
                // the screen reader.
                FieldGroupLabel(label),
                Text(
                  value,
                  style: context.type.body.copyWith(
                    color: colors.label,
                    fontFeatures: tabularValue ? AppTypography.tabular : null,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.md),
            Icon(
              Icons.chevron_right_rounded,
              size: AppSizing.iconMd,
              color: colors.labelTertiary,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      // One phrase — "Email, you@example.com" — instead of two disconnected
      // nodes the reader has to join up itself.
      return Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: content,
      );
    }

    return Semantics(
      button: true,
      label: '$label: $value. Edit',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        // Guarantees the row clears the minimum tap height even at the
        // smallest text size.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizing.minTouchTarget,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// A sheet for the one editable field, rather than a whole edit screen.
///
/// Design guideline — Modality: "Aim to keep modal tasks simple, short, and
/// streamlined."
class _EditNameSheet extends StatelessWidget {
  const _EditNameSheet({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenMargin,
        right: AppSpacing.screenMargin,
        top: AppSpacing.sm,
        // Lifts the sheet clear of the keyboard.
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit name',
            style: context.type.title3.copyWith(color: context.colors.label),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: controller,
            label: 'Name',
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
