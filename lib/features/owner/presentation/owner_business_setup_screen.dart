import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/primary_cta.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../businesses/domain/business_repository.dart';

/// First-run setup for a tailor: create the shop listing.
///
/// Design guideline — Onboarding: get people to the value quickly and ask only
/// for what you genuinely need. Four fields is the minimum a customer needs to
/// find this shop; everything else — photos, description, services — is added
/// afterwards from the management screens.
class OwnerBusinessSetupScreen extends ConsumerStatefulWidget {
  const OwnerBusinessSetupScreen({super.key});

  @override
  ConsumerState<OwnerBusinessSetupScreen> createState() =>
      _OwnerBusinessSetupScreenState();
}

class _OwnerBusinessSetupScreenState
    extends ConsumerState<OwnerBusinessSetupScreen> {
  final _name = TextEditingController();
  final _tagline = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();

  GeoPoint? _location;
  bool _isLocating = false;
  bool _isSubmitting = false;
  AppFailure? _failure;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isLocating = true;
      _failure = null;
    });

    try {
      final position = await ref
          .read(locationServiceProvider)
          .getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _location = position;
        _isLocating = false;
      });
    } catch (error) {
      if (!mounted) return;
      final failure = toAppFailure(error);
      setState(() {
        _isLocating = false;
        _failure = failure;
      });
      AppFeedback.showFailure(context, failure: failure);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final location = _location;
    if (location == null) {
      setState(
        () => _failure = const ValidationFailure(
          message: 'Set your shop location so customers nearby can find you.',
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
      _fieldErrors = const {};
    });

    try {
      final business = await ref
          .read(businessRepositoryProvider)
          .createBusiness(
            BusinessDraft(
              name: _name.text,
              address: _address.text,
              location: location,
              tagline: _tagline.text.trim().isEmpty ? null : _tagline.text,
              phone: _phone.text.trim().isEmpty ? null : _phone.text,
            ),
          );

      // Linking the listing to the account is what clears
      // `needsBusinessSetup`, which is how the router knows to move on.
      await ref.read(authRepositoryProvider).linkBusiness(business.id);

      if (!mounted) return;
      AppFeedback.showSuccess(
        context,
        message: 'Your shop is listed. Add your services next.',
      );

      // The router moves off this screen once the linked business clears
      // `needsBusinessSetup`, so this normally unmounts a frame later. Clearing
      // the flag anyway is the safety net: if that redirect ever fails to fire,
      // the alternative is a spinner that never resolves on a screen with no
      // back affordance, which is exactly the trap this had.
      if (mounted) setState(() => _isSubmitting = false);
    } catch (error) {
      if (!mounted) return;
      final failure = toAppFailure(error);
      setState(() {
        _isSubmitting = false;
        _failure = failure;
        _fieldErrors = failure is ValidationFailure
            ? failure.fieldErrors
            : const {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: const Text('Set up your shop'),
        actions: [
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            Text(
              'Welcome${user == null ? '' : ', ${user.name}'}',
              style: context.type.largeTitle.copyWith(color: colors.label),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add your shop so customers nearby can find and book you. You can '
              'change any of this later.',
              style: context.type.body.copyWith(color: colors.labelSecondary),
            ),

            const SizedBox(height: AppSpacing.xxxl),
            AppTextField(
              controller: _name,
              label: 'Shop name',
              hint: 'e.g. Sri Lakshmi Tailors',
              errorText: _fieldErrors['name'],
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icons.storefront_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _tagline,
              label: 'What you do',
              hint: "e.g. Men's & women's tailoring",
              helper: 'One short line shown under your name',
              textCapitalization: TextCapitalization.sentences,
              prefixIcon: Icons.label_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _address,
              label: 'Address',
              hint: 'Street, area, city',
              errorText: _fieldErrors['address'],
              maxLines: 2,
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icons.place_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _phone,
              label: 'Phone',
              hint: '+91 98765 43210',
              helper: 'Shown to customers who book you',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),

            const SizedBox(height: AppSpacing.xl),
            _LocationCapture(
              location: _location,
              isLocating: _isLocating,
              onCapture: _captureLocation,
            ),

            if (_failure != null) ...[
              const SizedBox(height: AppSpacing.lg),
              InlineNotice(message: _failure!.message),
            ],

            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'List my shop',
              isBusy: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

/// Captures the shop's coordinates from the device.
///
/// Standing in the shop and tapping a button is the most reliable way for a
/// non-technical owner to pin their location, and it avoids adding a map
/// dependency and an address-geocoding service to the MVP.
class _LocationCapture extends StatelessWidget {
  const _LocationCapture({
    required this.location,
    required this.isLocating,
    required this.onCapture,
  });

  final GeoPoint? location;
  final bool isLocating;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasLocation = location != null;

    return NearbyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasLocation
                    ? Icons.check_circle_rounded
                    : Icons.my_location_rounded,
                size: AppSizing.iconMd,
                // Monochrome: gold is reserved for ratings and the live
                // open-now state, so a captured location reads as white — the
                // same way this screen's open/closed settings do.
                color: hasLocation ? colors.label : colors.labelSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hasLocation ? 'Location set' : 'Shop location',
                  style: context.type.headline.copyWith(color: colors.label),
                ),
              ),
            ],
          ),
          if (hasLocation) ...[
            const SizedBox(height: AppSpacing.sm),
            // The coordinates are the value the card exists to show, so they
            // get their own line and tabular figures rather than being buried
            // mid-sentence.
            Text(
              'Saved as ${location!.latitude.toStringAsFixed(4)}, ${location!.longitude.toStringAsFixed(4)}',
              style: context.type.subheadEmphasis.copyWith(
                color: colors.label,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasLocation
                ? 'This is how far away customers will see you as.'
                : 'Stand in or near your shop and tap below. This is what puts you '
                      'on the nearby list.',
            style: context.type.footnote.copyWith(color: colors.labelSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: isLocating ? null : onCapture,
            icon: isLocating
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : const Icon(Icons.my_location_rounded, size: AppSizing.iconMd),
            label: Text(
              isLocating
                  ? 'Finding your location…'
                  : hasLocation
                  ? 'Update location'
                  : 'Use my current location',
            ),
            // Full width inside the card at the themed secondary height. The
            // stadium shape comes from the theme and is deliberately not
            // overridden — a rounded rectangle here would read as a different
            // button family from the white pill below.
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                AppSizing.secondaryButtonHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
