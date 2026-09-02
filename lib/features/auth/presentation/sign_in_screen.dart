import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/primary_cta.dart';
import 'auth_controller.dart';

/// Sign in with an email and password.
///
/// Design guideline — Managing accounts: ask for as little as possible, and
/// make the alternative path (creating an account) obvious rather than hidden.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Dismissing the keyboard first means the result — success or an inline
    // error — is visible without the user having to dismiss it themselves.
    FocusScope.of(context).unfocus();

    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.signIn(
      email: _email.text,
      password: _password.text,
    );

    if (!success && mounted) {
      final failure = ref.read(authControllerProvider).failure;
      if (failure != null) {
        AppFeedback.showFailure(context, failure: failure);
      }
    }
    // On success the router's redirect takes over — no navigation here.
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      AppFeedback.showInfo(
        context,
        message: 'Enter your email address first, then tap Forgot password.',
      );
      return;
    }

    final sent = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email);

    if (sent && mounted) {
      AppFeedback.showSuccess(
        context,
        message: 'If an account exists for $email, a reset link is on its way.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final formState = ref.watch(authControllerProvider);
    final fieldErrors = formState.fieldErrors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin,
              vertical: AppSpacing.xl,
            ),
            children: [
              const SizedBox(height: AppSpacing.xxl),
              const NearbyWordmark(fontSize: 36),
              const SizedBox(height: AppSpacing.lg),
              // The icon's dashed arc, straightened into a brand bar under
              // the wordmark.
              const BrandRule(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Welcome back',
                style: context.type.largeTitle.copyWith(color: colors.label),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sign in to book appointments and manage your bookings.',
                style: context.type.body.copyWith(color: colors.labelSecondary),
              ),
              const SizedBox(height: AppSpacing.xxxl),

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

              AppPasswordField(
                controller: _password,
                errorText: fieldErrors['password'],
                onChanged: (_) =>
                    ref.read(authControllerProvider.notifier).clearFailure(),
                onSubmitted: (_) => _submit(),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: formState.isSubmitting ? null : _resetPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              PrimaryButton(
                label: 'Sign in',
                isBusy: formState.isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.xl),

              // A Wrap, not a Row: at large accessibility text sizes the
              // prompt and the link no longer fit side by side, and wrapping
              // onto a second centred line beats clipping either of them.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'New to Nearby?',
                    style: context.type.subhead.copyWith(
                      color: colors.labelSecondary,
                    ),
                  ),
                  // The quiet action stays a themed TextButton — white
                  // semibold, no hue — per Monochrome & Gold's link rule.
                  TextButton(
                    onPressed: formState.isSubmitting
                        ? null
                        : () => context.pushNamed(AppRoutes.signUp),
                    child: const Text('Create an account'),
                  ),
                ],
              ),

              if (AppConfig.dataSource == DataSource.inMemory) ...[
                const SizedBox(height: AppSpacing.xxl),
                const _DemoCredentialsNotice(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown only when running against the in-memory backend, so the seeded
/// accounts are discoverable instead of guessable.
class _DemoCredentialsNotice extends StatelessWidget {
  const _DemoCredentialsNotice();

  @override
  Widget build(BuildContext context) {
    return const InlineNotice(
      tone: NoticeTone.info,
      icon: Icons.science_outlined,
      message:
          'Sample data mode — Firebase is not configured.\n'
          'Customer: customer@example.com\n'
          'Tailor: lakshmi@example.com\n'
          'Password for both: password123',
    );
  }
}
