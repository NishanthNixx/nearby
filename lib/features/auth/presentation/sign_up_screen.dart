import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/primary_cta.dart';
import '../domain/app_user.dart';
import 'auth_controller.dart';

/// Create an account, choosing whether you are booking or being booked.
///
/// The role choice comes first, because it changes what the rest of the app is
/// for and cannot be changed later without support.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  UserRole _role = UserRole.customer;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final success = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
          role: _role,
          phone: _phone.text.trim().isEmpty ? null : _phone.text,
        );

    if (!success && mounted) {
      final failure = ref.read(authControllerProvider).failure;
      if (failure != null) {
        AppFeedback.showFailure(context, failure: failure);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final formState = ref.watch(authControllerProvider);
    final fieldErrors = formState.fieldErrors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      // The bar carries the back affordance only. The heading lives in the
      // content as a large title, the same masthead-scale opening sign-in has;
      // repeating "Create account" in the bar would be a duplicate rather than
      // a hierarchy.
      appBar: AppBar(
        title: Text(
          'Create Account',
          style: context.type.headline.copyWith(color: colors.label),
        ),
        actions: [
          // Decorative, and marked as such: it is a brand flourish in the bar,
          // not an account button — there is no account to open yet.
          ExcludeSemantics(
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: AppSpacing.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary,
              ),
              child: Icon(
                Icons.person_rounded,
                size: 18,
                color: colors.onPrimary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin,
            ),
            children: [
              const SizedBox(height: AppSpacing.xs),
              // An eyebrow rather than a logo: the bar already names the
              // screen, so this line says what KIND of place this is.
              Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: AppSizing.iconMd,
                    color: colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'LOCAL CRAFT & SERVICES',
                    style: context.type.footnoteEmphasis.copyWith(
                      color: colors.labelSecondary,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Create account',
                style: context.type.title1.copyWith(color: colors.primary),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Discover and book trusted local services in your '
                'neighbourhood.',
                style: context.type.subhead.copyWith(
                  color: colors.labelSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              _RoleChoice(
                value: _role,
                onChanged: (role) => setState(() => _role = role),
              ),

              const SizedBox(height: AppSpacing.xl),
              // The stitch line: a seam between choosing a role and giving
              // your details.
              const BrandRule(height: 3),
              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                controller: _name,
                label: _role.isBusinessOwner ? 'Your name' : 'Full name',
                hint: 'e.g. Lakshmi Devi',
                errorText: fieldErrors['displayName'],
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                prefixIcon: Icons.person_outline_rounded,
                onChanged: (_) =>
                    ref.read(authControllerProvider.notifier).clearFailure(),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _email,
                label: 'Email',
                hint: 'you@example.com',
                errorText: fieldErrors['email'],
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                prefixIcon: Icons.mail_outline_rounded,
                onChanged: (_) =>
                    ref.read(authControllerProvider.notifier).clearFailure(),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _phone,
                label: 'Phone',
                hint: '+91 98765 43210',
                // Marked optional in the label rather than only being
                // omittable, so nobody wonders whether they have to fill it.
                helper: _role.isBusinessOwner
                    ? 'Shown to customers so they can reach you'
                    : 'Optional — helps the business contact you',
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                prefixIcon: Icons.phone_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),

              AppPasswordField(
                controller: _password,
                errorText: fieldErrors['password'],
                helper: 'At least 8 characters',
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) =>
                    ref.read(authControllerProvider.notifier).clearFailure(),
                onSubmitted: (_) => _submit(),
              ),

              const SizedBox(height: AppSpacing.xl),
              // A quiet note, not a checkbox: there is nothing to opt into, so
              // a control would imply a choice that is not being offered.
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.bgGrouped,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: AppSizing.iconSm + 2,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'By continuing, you agree to our ',
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: AppTypography.medium,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: AppTypography.medium,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        style: context.type.caption.copyWith(
                          color: colors.labelSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              // Built here rather than through PrimaryButton: that helper pins
              // the button to a 56pt box, and a two-word label at the 2x text
              // ceiling is wider than the pill — it has to be free to take a
              // second line and grow. ActionPill supplies the same leather
              // gradient and measured ink, without the height lock.
              ActionPill(
                enabled: !formState.isSubmitting,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: actionButtonStyle,
                    onPressed: formState.isSubmitting ? null : _submit,
                    child: formState.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppGradients.onAction,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Create account',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: AppSizing.iconMd,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // A Wrap, not a Row: at large accessibility text sizes the
              // prompt and the link no longer fit side by side, and wrapping
              // onto a second centred line beats clipping either of them.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: context.type.subhead.copyWith(
                      color: colors.labelSecondary,
                    ),
                  ),
                  // Quiet action = themed TextButton (white semibold, no hue),
                  // per Monochrome & Gold's link rule.
                  TextButton(
                    onPressed: formState.isSubmitting
                        ? null
                        : () => context.pop(),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// The role choice: two cards, exactly one of them filled.
///
/// Built on [NearbyCard] rather than a bordered segment control because the
/// card primitive already encodes both rules this control needs — a dark
/// surface carries no hairline, and a chosen cell inverts to a white fill with
/// black text, the same move as a selected date or time slot in the booking
/// flow. One selection idiom across the app means the state never has to be
/// learned twice.
class _RoleChoice extends StatelessWidget {
  const _RoleChoice({required this.value, required this.onChanged});

  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoleCard(
          title: 'I want to book services',
          subtitle: 'Find businesses nearby and book appointments',
          icon: Icons.search_rounded,
          isSelected: value == UserRole.customer,
          onTap: () => onChanged(UserRole.customer),
        ),
        const SizedBox(height: AppSpacing.md),
        _RoleCard(
          title: 'I offer services',
          subtitle: 'List your shop and manage your appointments',
          icon: Icons.storefront_rounded,
          isSelected: value == UserRole.businessOwner,
          onTap: () => onChanged(UserRole.businessOwner),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Every foreground flips with the fill, so the inverted card reads as
    // deliberately chosen rather than as a colour accident.
    final titleColor = isSelected ? colors.onPrimary : colors.label;
    final supportColor = isSelected
        // A softened version of the inverted ink, not one of the grey tokens:
        // the greys are tuned against the near-black ground and wash out on a
        // white fill. At this alpha the footnote still clears 4.5:1.
        ? colors.onPrimary.withValues(alpha: 0.8)
        : colors.labelSecondary;

    return NearbyCard(
      onTap: onTap,
      isSelected: isSelected,
      // One sentence for the whole cell; the card's own Semantics carries the
      // button role and the selected state.
      semanticsLabel: '$title. $subtitle',
      child: Row(
        // Top-aligned, because at large text sizes the two text lines grow and
        // the glyphs must stay beside the title rather than drift to the middle.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The glyph sits in its own disc rather than bare on the fill. On the
          // selected card that disc is a lightened wash of the inverted ink, so
          // it reads as a chip cut out of the brown rather than an icon dropped
          // on top of it.
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? colors.onPrimary.withValues(alpha: 0.14)
                  : colors.bgGrouped,
            ),
            child: Icon(
              icon,
              size: AppSizing.iconLg,
              color: isSelected ? colors.onPrimary : colors.labelSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.type.headline.copyWith(color: titleColor),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: context.type.subhead.copyWith(color: supportColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // A glyph as well as the inversion, so the choice is never carried by
          // the fill alone.
          //
          // Design guideline — Accessibility > Vision: "Convey information
          // with more than color alone."
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colors.onPrimary : colors.bgGrouped,
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, size: 16, color: colors.primary)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
