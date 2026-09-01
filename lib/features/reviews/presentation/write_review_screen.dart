import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/illustrations.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/primary_cta.dart';
import '../../../core/widgets/star_rating.dart';
import '../../bookings/presentation/booking_providers.dart';
import '../domain/review_repository.dart';

/// Leave a review for a completed appointment.
///
/// Design guideline — Ratings and reviews > Best practices: "Ask for a rating
/// only after people have demonstrated engagement with your app... you might
/// prompt people when they complete a game level or a significant task."
///
/// Nearby never interrupts to ask. The prompt appears as an action on a
/// completed appointment, which is the natural stopping point, and the customer
/// chooses when to take it.
class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  final _comment = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit(String businessId) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    try {
      await ref
          .read(reviewRepositoryProvider)
          .submitReview(
            ReviewDraft(
              bookingId: widget.bookingId,
              businessId: businessId,
              rating: _rating,
              comment: _comment.text,
            ),
          );

      if (!mounted) return;

      AppFeedback.showSuccess(
        context,
        message: 'Thanks — your review is live.',
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      final failure = toAppFailure(error);
      setState(() {
        _isSubmitting = false;
        _failure = failure;
      });
      AppFeedback.showFailure(context, failure: failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final booking = ref.watch(bookingByIdProvider(widget.bookingId));

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave a review')),
        body: const ErrorView(failure: NotFoundFailure(what: 'appointment')),
      );
    }

    if (!booking.canReview) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave a review')),
        body: EmptyView(
          illustration: NearbyIllustration.noReviews,
          icon: Icons.rate_review_outlined,
          title: booking.hasReview ? 'Already reviewed' : 'Not yet',
          message: booking.hasReview
              ? 'You have already left a review for this appointment.'
              : 'You can review an appointment once the tailor marks it completed.',
          actionLabel: 'Back to bookings',
          onAction: () => context.pop(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(title: const Text('Leave a review')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            Text(
              'How was ${booking.businessName}?',
              style: context.type.title2.copyWith(color: colors.label),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${booking.serviceName} · ${Fmt.dayMonthYear(booking.startTime)}',
              style: context.type.subhead.copyWith(
                color: colors.labelSecondary,
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            NearbyCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: StarRatingInput(
                value: _rating,
                onChanged: (value) => setState(() {
                  _rating = value;
                  _failure = null;
                }),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _comment,
              label: 'Add a comment',
              hint: 'What was the fit, the finish, the service like?',
              helper:
                  'Optional · up to ${AppConfig.maxReviewLength} characters',
              maxLines: 5,
              maxLength: AppConfig.maxReviewLength,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
            ),

            if (_failure != null) ...[
              const SizedBox(height: AppSpacing.lg),
              InlineNotice(message: _failure!.message),
            ],

            const SizedBox(height: AppSpacing.xl),
            Text(
              'Your name is shown with your review. Reviews help other people in '
              'your area choose a tailor.',
              style: context.type.caption.copyWith(
                color: colors.labelSecondary,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PrimaryCtaBar(
        label: 'Post review',
        isBusy: _isSubmitting,
        // Disabled until a rating is chosen, with the reason stated rather than
        // left for the customer to work out.
        supportingText: _rating == 0
            ? 'Choose a star rating to continue'
            : null,
        onPressed: _rating == 0 ? null : () => _submit(booking.businessId),
      ),
    );
  }
}
