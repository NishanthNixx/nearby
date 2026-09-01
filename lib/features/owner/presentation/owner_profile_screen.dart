import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/indicators.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/primary_cta.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../businesses/domain/business.dart';
import '../../businesses/domain/business_repository.dart';
import '../../businesses/presentation/business_providers.dart';

/// The shop's own details, plus the switch that pauses bookings.
///
/// The pause control is the most consequential thing here — it takes the shop
/// off the bookable list — so it gets its own card with the consequence spelled
/// out, rather than being one row in a list of settings.
class OwnerProfileScreen extends ConsumerWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final businessAsync = ref.watch(myBusinessProvider);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: Text(
          'Shop',
          style: context.type.title2.copyWith(color: colors.label),
        ),
        toolbarHeight: 64,
        actions: [
          TextButton(
            onPressed: () => _signOut(context, ref),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: businessAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myBusinessProvider),
        ),
        data: (business) {
          if (business == null) return const SizedBox.shrink();
          return _ShopBody(business: business);
        },
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppFeedback.confirmDestructive(
      context,
      title: 'Sign out?',
      message:
          'Your shop stays listed and customers can still book you. You will '
          'need to sign in again to see your appointments.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay signed in',
    );

    if (!confirmed) return;
    await ref.read(authControllerProvider.notifier).signOut();
  }
}

class _ShopBody extends ConsumerWidget {
  const _ShopBody({required this.business});

  final Business business;

  Future<void> _togglePause(BuildContext context, WidgetRef ref) async {
    final pausing = business.isAcceptingBookings;

    if (pausing) {
      final confirmed = await AppFeedback.confirmDestructive(
        context,
        title: 'Pause new bookings?',
        message:
            'Your shop stays listed with all its details, but customers will not '
            'be able to book. Appointments you already have are unaffected.',
        confirmLabel: 'Pause bookings',
        cancelLabel: 'Keep taking bookings',
      );
      if (!confirmed) return;
    }

    try {
      await ref
          .read(businessRepositoryProvider)
          .setAcceptingBookings(business.id, !pausing);

      if (!context.mounted) return;
      AppFeedback.showSuccess(
        context,
        message: pausing
            ? 'Bookings paused. Turn this back on when you are ready.'
            : 'You are taking bookings again.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AppFeedback.showFailure(context, failure: toAppFailure(error));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ShopEditorSheet(business: business),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // --- Identity -------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.sm,
            AppSpacing.screenMargin,
            0,
          ),
          child: NearbyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.name,
                  style: context.type.title3.copyWith(color: colors.label),
                ),
                if (business.tagline != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    business.tagline!,
                    style: context.type.subhead.copyWith(
                      color: colors.labelSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RatingBadge(
                      average: business.ratingAverage,
                      count: business.ratingCount,
                    ),
                    StatusPill.openState(
                      isOpen: business.isOpenAt(DateTime.now()),
                      context: context,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => _edit(context, ref),
                  icon: const Icon(Icons.edit_outlined, size: AppSizing.iconMd),
                  label: const Text('Edit shop details'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      AppSizing.secondaryButtonHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- Taking bookings ------------------------------------------
        const SectionHeader(title: 'Taking bookings'),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
          ),
          child: NearbyCard(
            // The most consequential control on the screen, so it gets room a
            // settings row would not: deeper padding, the switch on the title
            // line, and the consequence spelled out across the full card width
            // where it still reads at large text sizes.
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      business.isAcceptingBookings
                          ? Icons.event_available_rounded
                          : Icons.pause_circle_outline_rounded,
                      size: AppSizing.iconLg,
                      // Monochrome: whether the shop takes bookings is a
                      // setting, not the live open-now state, and gold belongs
                      // to ratings and open-now alone.
                      color: business.isAcceptingBookings
                          ? colors.label
                          : colors.labelSecondary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        business.isAcceptingBookings
                            ? 'Open for bookings'
                            : 'Bookings paused',
                        style: context.type.headline.copyWith(
                          color: colors.label,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // The themed switch already inverts when on — white track,
                    // black thumb — which is the selection rule, so it needs no
                    // colour of its own.
                    Semantics(
                      label: 'Taking bookings',
                      toggled: business.isAcceptingBookings,
                      excludeSemantics: true,
                      child: Switch(
                        value: business.isAcceptingBookings,
                        onChanged: (_) => _togglePause(context, ref),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  business.isAcceptingBookings
                      ? 'Customers nearby can find and book you.'
                      : 'You are still listed, but nobody can book.',
                  style: context.type.footnote.copyWith(
                    color: colors.labelSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- Details --------------------------------------------------
        const SectionHeader(title: 'Details customers see'),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
          ),
          child: NearbyCardList(
            children: [
              _InfoRow(
                icon: Icons.place_outlined,
                label: 'Address',
                value: business.address,
              ),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: business.phone ?? 'Not set',
              ),
              _InfoRow(
                icon: Icons.notes_outlined,
                label: 'About',
                value: business.description ?? 'Not set',
              ),
              _InfoRow(
                icon: Icons.my_location_outlined,
                label: 'Location',
                value:
                    '${business.location.latitude.toStringAsFixed(4)}, ${business.location.longitude.toStringAsFixed(4)}',
                numeric: true,
              ),
              _InfoRow(
                icon: Icons.event_note_outlined,
                label: 'Listed since',
                value: Fmt.dayMonthYear(business.createdAt),
                numeric: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.numeric = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Coordinates and dates get tabular figures so a column of them lines up.
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      // One phrase per row, in natural case, so the reader hears
      // "Address, 14 Gandhi Road" rather than two disconnected fragments and
      // never spells out the letterspaced capitals below.
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // Optically centres the glyph on the micro-label's cap height.
              padding: const EdgeInsets.only(top: AppSpacing.xxs - 1),
              child: Icon(
                icon,
                size: AppSizing.iconMd,
                color: colors.labelSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // The label sits above its value as a micro-caption rather than in
            // a fixed-width gutter: at large text sizes a 76pt column squeezed
            // the value into a ribbon, and these rows are not a table whose
            // columns need to align.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: context.type.caption.copyWith(
                      color: colors.labelSecondary,
                      fontWeight: AppTypography.semibold,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    value,
                    style: context.type.body.copyWith(
                      color: colors.label,
                      fontFeatures: numeric ? AppTypography.tabular : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edits the shop details a customer sees.
class _ShopEditorSheet extends ConsumerStatefulWidget {
  const _ShopEditorSheet({required this.business});

  final Business business;

  @override
  ConsumerState<_ShopEditorSheet> createState() => _ShopEditorSheetState();
}

class _ShopEditorSheetState extends ConsumerState<_ShopEditorSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.business.name,
  );
  late final TextEditingController _tagline = TextEditingController(
    text: widget.business.tagline ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.business.description ?? '',
  );
  late final TextEditingController _address = TextEditingController(
    text: widget.business.address,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.business.phone ?? '',
  );

  bool _isSaving = false;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
    _description.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _fieldErrors = const {};
    });

    try {
      await ref
          .read(businessRepositoryProvider)
          .updateBusiness(
            widget.business.id,
            BusinessDraft(
              name: _name.text,
              address: _address.text,
              // Location is not edited here — it is captured from the device on
              // setup, and re-pinning it belongs with a deliberate action rather
              // than a text form.
              location: widget.business.location,
              tagline: _tagline.text.trim().isEmpty ? null : _tagline.text,
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text,
              phone: _phone.text.trim().isEmpty ? null : _phone.text,
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(context, message: 'Shop details saved.');
    } catch (error) {
      if (!mounted) return;
      final failure = toAppFailure(error);
      setState(() {
        _isSaving = false;
        _fieldErrors = failure is ValidationFailure
            ? failure.fieldErrors
            : const {};
      });
      AppFeedback.showFailure(context, failure: failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenMargin,
        right: AppSpacing.screenMargin,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit shop details',
              style: context.type.title3.copyWith(color: context.colors.label),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _name,
              label: 'Shop name',
              errorText: _fieldErrors['name'],
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _tagline,
              label: 'What you do',
              hint: "e.g. Men's & women's tailoring",
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _description,
              label: 'About your shop',
              hint: 'What makes your work worth the trip?',
              maxLines: 4,
              maxLength: 400,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _address,
              label: 'Address',
              errorText: _fieldErrors['address'],
              maxLines: 2,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _phone,
              label: 'Phone',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: 'Save changes',
                    isBusy: _isSaving,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
