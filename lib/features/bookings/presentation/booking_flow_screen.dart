import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/illustrations.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/primary_cta.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../businesses/domain/service_offering.dart';
import '../domain/booking.dart';
import 'booking_flow_controller.dart';

/// The booking flow: service, schedule (date and time together), confirm.
///
/// One screen with a single linear path, rather than a stack of pushed routes.
///
/// Design guideline — Modality > Best practices: "Aim to keep modal tasks
/// simple, short, and streamlined... Take care to avoid creating a modal
/// experience that feels like an app within your app."
class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({
    super.key,
    required this.businessId,
    this.preselectedServiceId,
  });

  final String businessId;
  final String? preselectedServiceId;

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  final _noteController = TextEditingController();

  BookingFlowArgs get _args => BookingFlowArgs(
    businessId: widget.businessId,
    serviceId: widget.preselectedServiceId,
  );

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    final controller = ref.read(bookingFlowControllerProvider(_args).notifier);

    // Back walks the steps; only from the first step does it leave the flow.
    if (controller.back()) return;

    final state = ref.read(bookingFlowControllerProvider(_args));

    // Nothing chosen yet: leaving costs the user nothing, so don't interrupt.
    if (state.selectedSlot == null && state.selectedDate == null) {
      if (mounted) context.pop();
      return;
    }

    // Design guideline — Modality: "help people avoid data loss by getting
    // confirmation before closing a modal view."
    final discard = await AppFeedback.confirmDestructive(
      context,
      title: 'Discard this booking?',
      message: 'Your selected service and time will not be saved.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep booking',
    );

    if (discard && mounted) context.pop();
  }

  Future<void> _submit() async {
    final controller = ref.read(bookingFlowControllerProvider(_args).notifier);
    final success = await controller.submit();

    if (!mounted) return;

    if (!success) {
      final failure = ref.read(bookingFlowControllerProvider(_args)).failure;
      if (failure != null) {
        AppFeedback.showFailure(context, failure: failure);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(bookingFlowControllerProvider(_args));
    final controller = ref.read(bookingFlowControllerProvider(_args).notifier);

    if (state.isComplete) {
      return _BookingConfirmedScreen(booking: state.createdBooking!);
    }

    if (state.isLoadingBusiness) {
      return Scaffold(
        appBar: AppBar(title: const Text('Book appointment')),
        body: const _FlowSkeleton(),
      );
    }

    final failure = state.failure;
    if (state.business == null && failure != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Book appointment')),
        body: ErrorView(failure: failure),
      );
    }

    return PopScope(
      // Intercepted so the step-back and discard-confirmation logic runs on a
      // system back gesture too, not just the toolbar button.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: colors.bgBase,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
          title: Text(state.step.title),
          // The scaler is read here, where there is a context, because a
          // PreferredSizeWidget has to declare its height without one.
          bottom: _StepProgress(
            state: state,
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: _StepBody(
            args: _args,
            state: state,
            noteController: _noteController,
          ),
        ),
        bottomNavigationBar: _FlowCta(
          state: state,
          onNext: controller.next,
          onSubmit: _submit,
        ),
      ),
    );
  }
}

/// Height of one line set in [style] at [scaler].
///
/// Laid out rather than multiplied out: the engine rounds a line box up to a
/// whole pixel, so `fontSize * height` under-reports by up to a pixel — which
/// is exactly enough to overflow a cell sized from it. (It did: the date strip
/// overflowed by half a pixel at 1.5x.) Every derived height on this screen
/// goes through here.
double _lineHeight(TextStyle style, TextScaler scaler) {
  final painter = TextPainter(
    // Any glyph does: the line box comes from the style's metrics, not the text.
    text: TextSpan(text: '0', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// A thin progress bar plus "Step 2 of 3".
///
/// Design guideline — Loading > Showing progress: use a determinate indicator
/// when the length is known. Here it is, so the customer always knows how much
/// is left.
class _StepProgress extends StatelessWidget implements PreferredSizeWidget {
  const _StepProgress({required this.state, required this.textScaler});

  final BookingFlowState state;

  /// Passed in rather than read off the context, because [preferredSize] has to
  /// answer before a build.
  final TextScaler textScaler;

  /// Hairline: the bar is a progress cue, not a component in its own right.
  static const double _barHeight = 3;

  // Both numbers come from the state's own list of visible steps, so the label
  // and the bar cannot disagree with what is on screen.
  int get _total => state.stepCount;
  int get _current => state.stepNumber;

  @override
  Size get preferredSize {
    // Derived from the label's own metrics rather than fixed: an AppBar clips
    // its bottom widget to exactly this height, so a constant would slice the
    // "Step 2 of 3" line off at large text sizes.
    final line = _lineHeight(AppTypography.caption, textScaler);
    return Size.fromHeight(line + AppSpacing.xs + _barHeight + AppSpacing.sm);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Step $_current of $_total',
            excludeSemantics: true,
            child: Text(
              'Step $_current of $_total',
              style: context.type.caption.copyWith(
                color: colors.labelSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // The step bar is the one element guaranteed to be on screen before
          // anything is selected, so it carries the spectrum: the filled length
          // sweeps the full icon ramp, putting a cool and a warm hue on the
          // screen even while the CTA is still disabled and grey.
          //
          // It can take the FULL sweep where the CTA cannot, because nothing is
          // written on it — the 3.55:1 luminance span that makes the sweep
          // unusable behind a label is irrelevant to a bare 4pt rule.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: ColoredBox(
              color: colors.separator,
              child: SizedBox(
                height: _barHeight,
                width: double.infinity,
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: _current / _total,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppGradients.brand),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBody extends ConsumerWidget {
  const _StepBody({
    required this.args,
    required this.state,
    required this.noteController,
  });

  final BookingFlowArgs args;
  final BookingFlowState state;
  final TextEditingController noteController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bookingFlowControllerProvider(args).notifier);

    return switch (state.step) {
      BookingStep.service => _ServiceStep(
        services: state.services,
        selected: state.selectedService,
        onSelect: controller.selectService,
      ),
      BookingStep.schedule => _ScheduleStep(
        state: state,
        onSelectDate: controller.selectDate,
        onSelectSlot: controller.selectSlot,
        onRefresh: controller.refreshSlots,
      ),
      BookingStep.confirm => _ConfirmStep(
        state: state,
        noteController: noteController,
        onNoteChanged: controller.setNote,
        onEditStep: controller.goToStep,
      ),
    };
  }
}

// --- Step 1: service ---------------------------------------------------------

class _ServiceStep extends StatelessWidget {
  const _ServiceStep({
    required this.services,
    required this.selected,
    required this.onSelect,
  });

  final List<ServiceOffering> services;
  final ServiceOffering? selected;
  final ValueChanged<ServiceOffering> onSelect;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const EmptyView(
        illustration: NearbyIllustration.noServices,
        icon: Icons.design_services_outlined,
        title: 'No services listed',
        message:
            'This tailor has not added any services yet, so there is nothing to book.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final colors = context.colors;
        final service = services[index];
        final isSelected = selected?.id == service.id;

        // NearbyCard inverts to a white fill when selected, so every colour
        // inside it has to invert too. The earlier pair — onPrimaryContainer on
        // a tinted primaryContainer wash — describes a surface that no longer
        // exists in the scheme.
        final foreground = isSelected ? colors.onPrimary : colors.label;
        final supporting = isSelected
            ? colors.onPrimary.withValues(alpha: 0.8)
            : colors.labelSecondary;

        return NearbyCard(
          isSelected: isSelected,
          onTap: () => onSelect(service),
          semanticsLabel:
              '${service.name}, ${service.price == 0 ? 'free' : 'from ${Fmt.price(service.price)}'}, '
              '${Fmt.duration(service.durationMinutes)}'
              '${isSelected ? ', selected' : ''}',
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: context.type.headline.copyWith(color: foreground),
                    ),
                    if (service.description != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        service.description!,
                        style: context.type.footnote.copyWith(
                          color: supporting,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${Fmt.duration(service.durationMinutes)} · ${service.price == 0 ? 'Free' : Fmt.priceFrom(service.price)}',
                      style: context.type.subheadEmphasis.copyWith(
                        // Full-strength when selected: duration and price are
                        // the numbers the choice is actually made on.
                        color: isSelected
                            ? colors.onPrimary
                            : colors.labelSecondary,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                // On an inverted card the glyph has to take the card's opposite
                // value; a white mark on a white fill is no mark at all.
                color: isSelected ? colors.onPrimary : colors.labelTertiary,
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- Step 2: schedule (date + time) -------------------------------------------

/// True when two instants fall on the same calendar day.
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Width of one date cell. A fixed width keeps the strip's rhythm uniform;
/// it widens with the text scale so a two-digit day at 2x never clips.
double _dateCellWidth(BuildContext context) {
  final scale =
      MediaQuery.textScalerOf(context).scale(AppTypography.title3.fontSize!) /
      AppTypography.title3.fontSize!;
  return 64 * math.max(1.0, scale);
}

/// Height of the date strip: the cell's three stacked text lines plus padding,
/// derived from the text metrics so larger type gets a taller strip rather
/// than clipped cells. Never below the minimum touch target.
double _dateStripHeight(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  final content =
      _lineHeight(AppTypography.caption, scaler) * 2 +
      _lineHeight(AppTypography.title3, scaler) +
      AppSpacing.xxs * 2 +
      AppSpacing.sm * 2;
  return math.max(AppSizing.minTouchTarget, content);
}

/// Date strip and time grid on one screen, the way the reference books:
/// picking a day and picking a slot are one decision, so they share a step.
class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({
    required this.state,
    required this.onSelectDate,
    required this.onSelectSlot,
    required this.onRefresh,
  });

  final BookingFlowState state;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<TimeSlot> onSelectSlot;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final dates = state.selectableDates;

    if (dates.isEmpty) {
      return const EmptyView(
        illustration: NearbyIllustration.noAvailability,
        icon: Icons.event_busy_rounded,
        title: 'No open days coming up',
        message:
            'This tailor has no trading days in the next month. Try another tailor nearby.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: context.colors.primary,
      child: ListView(
        // Always scrollable so pull-to-refresh works even when the content
        // fits the viewport.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: [
          // Micro-labels over each block, in the reference's LATEST VISIT /
          // DATE / TIME style. SectionHeader renders the recipe; only its
          // default section padding is overridden to fit this screen.
          const SectionHeader(
            title: 'Date',
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              0,
              AppSpacing.screenMargin,
              AppSpacing.md,
            ),
          ),
          _DateStrip(
            dates: dates,
            selected: state.selectedDate,
            onSelect: onSelectDate,
          ),
          const SectionHeader(
            title: 'Time',
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.xl,
              AppSpacing.screenMargin,
              AppSpacing.md,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin,
            ),
            child: _TimeSection(
              state: state,
              onSelect: onSelectSlot,
              onRefresh: onRefresh,
            ),
          ),
        ],
      ),
    );
  }
}

/// One horizontal row of uniform date cells.
///
/// A strip rather than the old three-across grid: it keeps the days in a
/// single scannable line above the times, and a closed day simply is not in
/// the list, so no cell is ever disabled.
class _DateStrip extends StatefulWidget {
  const _DateStrip({
    required this.dates,
    required this.selected,
    required this.onSelect,
  });

  final List<DateTime> dates;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<_DateStrip> {
  ScrollController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Starts the strip at the selected day — which matters when the customer
  /// comes back from the confirm step to a date deep in the list.
  double _initialOffset(BuildContext context) {
    final selected = widget.selected;
    if (selected == null) return 0;
    final index = widget.dates.indexWhere((d) => _sameDay(d, selected));
    if (index <= 0) return 0;
    return index * (_dateCellWidth(context) + AppSpacing.sm);
  }

  @override
  Widget build(BuildContext context) {
    // Created on first build rather than initState so the initial offset can
    // read the text-scaled cell width off the inherited MediaQuery.
    _controller ??= ScrollController(
      initialScrollOffset: _initialOffset(context),
    );

    return SizedBox(
      height: _dateStripHeight(context),
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
        ),
        itemCount: widget.dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final date = widget.dates[index];
          return _DateCell(
            date: date,
            isSelected:
                widget.selected != null && _sameDay(widget.selected!, date),
            // The month is named only where it changes; repeating it on
            // every cell would out-shout the day numbers.
            showMonth:
                index == 0 || widget.dates[index - 1].month != date.month,
            onTap: () => widget.onSelect(date),
          );
        },
      ),
    );
  }
}

/// One day in the strip: weekday on top, day number, month when it changes.
/// Whether a date cell carries its light-mode hairline. Unselected cells in
/// light need one because surface-white on the bone ground is only a 1.12:1
/// value step; a selected cell is an indigo fill and needs no outline.
bool _hasHairline(AppColors colors, bool isSelected) =>
    colors.brightness == Brightness.light && !isSelected;

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.isSelected,
    required this.showMonth,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool showMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Selection inverts the cell — white fill, black text — the same rule as
    // the primary button, so "chosen" always looks the same everywhere.
    // Unselected cells are plain surface with no border: value, not outline,
    // separates them from the near-black ground.
    // 0.80, not 0.70: on the indigo fill a 70% white measures 4.31:1 and APCA
    // Lc 54.8, under both the 4.5:1 and Lc 60 floors for small text. 80% gives
    // 5.16:1 / Lc 65.7. The old value was safe against the previous pale fill
    // and quietly stopped being safe when primary went dark.
    final secondary = isSelected
        ? colors.onPrimary.withValues(alpha: 0.8)
        : colors.labelSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      // Natural case for the reader, even though the cell displays "FRI".
      label: '${Fmt.fullDate(date)}${isSelected ? ', selected' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: _dateCellWidth(context),
            // The hairline below is drawn INSIDE the box, so the padding gives
            // back exactly the space it takes. Without this the cell overflows
            // its 59pt slot in light mode, and every cell would jump 2pt as
            // selection removed the border.
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: _hasHairline(colors, isSelected)
                  ? AppSpacing.sm - 1
                  : AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected ? colors.primary : colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              // A light-only hairline: an unselected cell is surface-white on an
              // off-white ground, so in light there is no value gap to separate
              // them. Dark needs none — the surface is already lighter than the
              // near-black ground. Same rule NearbyCard follows.
              border: _hasHairline(colors, isSelected)
                  ? Border.all(color: colors.separator)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Fmt.weekdayShort(date).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption.copyWith(
                    color: secondary,
                    fontWeight: AppTypography.medium,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  date.day.toString(),
                  maxLines: 1,
                  style: context.type.title3.copyWith(
                    color: isSelected ? colors.onPrimary : colors.label,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                // Always laid out, made invisible when the month repeats, so
                // every cell keeps exactly the same height.
                Text(
                  Fmt.dayMonth(date).split(' ').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption.copyWith(
                    color: showMonth ? secondary : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Time grid -----------------------------------------------------------------

/// How many time slots fit across, at the current text size.
///
/// Design guideline — Typography > Supporting scalable text: "Consider adjusting
/// your layout at large font sizes." Three columns is comfortable by default;
/// past roughly 1.3x the labels need two, and past 1.8x they need one.
int _slotColumns(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(15) / 15;
  if (scale >= 1.8) return 1;
  if (scale >= 1.3) return 2;
  return 3;
}

/// Cell height: one line of the chip's label plus padding, never below the
/// minimum control size.
double _slotHeight(BuildContext context) {
  final line = _lineHeight(
    AppTypography.subheadEmphasis,
    MediaQuery.textScalerOf(context),
  );
  return math.max(AppSizing.minTouchTarget, line + AppSpacing.md * 2);
}

/// The time block inside the schedule step.
///
/// Distinct from a standalone step: the parent supplies the scroll view and the
/// pull-to-refresh, so this is a plain column. Splitting it out keeps the date
/// and time blocks independently readable now that they share one screen.
class _TimeSection extends StatelessWidget {
  const _TimeSection({
    required this.state,
    required this.onSelect,
    required this.onRefresh,
  });

  final BookingFlowState state;
  final ValueChanged<TimeSlot> onSelect;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (state.isLoadingSlots && state.slots == null) {
      return const _SlotsSkeleton();
    }

    final slots = state.slots ?? const <TimeSlot>[];

    // Inline rather than a full-screen empty view: the date strip above stays
    // on screen, because choosing a different date is the actual way out.
    if (slots.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineNotice(
            tone: NoticeTone.info,
            icon: Icons.event_busy_rounded,
            message: state.selectedDate == null
                ? 'No times available on this day. Try another date.'
                : 'Every slot on ${Fmt.fullDate(state.selectedDate!)} is taken '
                      'or has passed. Try another date above.',
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onRefresh,
              child: const Text('Check again'),
            ),
          ),
        ],
      );
    }

    final available = state.availableSlots.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                available == 0
                    ? 'No times left on this date'
                    : '$available of ${slots.length} times available',
                style: context.type.footnote.copyWith(
                  color: colors.labelSecondary,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ),
            if (state.isLoadingSlots)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: colors.labelSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // A uniform grid rather than a wrap: a column of times is far quicker
        // to scan than ragged rows, and every cell is the same target size.
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _slotColumns(context),
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: _slotHeight(context),
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            return _SlotChip(
              slot: slot,
              isSelected: state.selectedSlot == slot,
              onTap: () => onSelect(slot),
            );
          },
        ),

        const SizedBox(height: AppSpacing.lg),
        // Explains the struck-through labels, so an unavailable slot does not
        // read as a bug.
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: AppSizing.iconSm,
              color: colors.labelSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Crossed-out times are already booked or too soon. Pull down '
                'to check for new openings.',
                style: context.type.caption.copyWith(
                  color: colors.labelSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One time slot.
///
/// Unavailable slots stay on screen, struck through and dimmed, rather than
/// being removed: seeing that 5:00 is taken is more informative than seeing a
/// gap, and it keeps the grid stable as bookings land.
///
/// Three states, three surface values and no outlines: a takeable slot is a
/// filled surface tile, a taken one is bare ground, and the chosen one inverts
/// to white. The grid then reads as "these are the tiles you can take" at a
/// glance, before a single label is read.
class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  final TimeSlot slot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = slot.isAvailable;

    final Color background;
    final Color foreground;

    if (isSelected) {
      background = colors.primary;
      foreground = colors.onPrimary;
    } else if (enabled) {
      background = colors.surface;
      foreground = colors.label;
    } else {
      // Nothing at all behind a taken slot — it recedes into the ground rather
      // than presenting itself as another tile to consider.
      background = Colors.transparent;
      foreground = colors.labelTertiary;
    }

    return Semantics(
      button: enabled,
      selected: isSelected,
      enabled: enabled,
      label:
          '${Fmt.time(slot.start)}'
          '${enabled ? '' : ', unavailable'}'
          '${isSelected ? ', selected' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          // Fills the grid cell. A Container with an alignment expands to the
          // maximum width it is offered, which inside a Wrap meant one
          // full-width chip per row — the grid gives it a bounded cell instead.
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: background,
            // The same radius as a date cell, because they are the same kind of
            // object: one uniform tile in a field of choices.
            borderRadius: BorderRadius.circular(AppRadius.md),
            // Light-only hairline, for the same reason the date cells carry
            // one: an unselected tile is surface-white on an off-white ground
            // and would otherwise be invisible. Dark separates by value.
            border: colors.brightness == Brightness.light && !isSelected
                ? Border.all(color: colors.separator)
                : null,
          ),
          child: Text(
            Fmt.time(slot.start),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.type.subheadEmphasis.copyWith(
              color: foreground,
              fontFeatures: AppTypography.tabular,
              // A line through the label, not just a lighter colour — the
              // unavailable state survives greyscale and colour blindness.
              decoration: enabled ? null : TextDecoration.lineThrough,
              decorationColor: colors.labelTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Step 3: confirm ---------------------------------------------------------

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.state,
    required this.noteController,
    required this.onNoteChanged,
    required this.onEditStep,
  });

  final BookingFlowState state;
  final TextEditingController noteController;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<BookingStep> onEditStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final business = state.business!;
    final service = state.selectedService!;
    final slot = state.selectedSlot!;

    return ListView(
      // The section headers carry the horizontal margin themselves, so the list
      // insets only vertically and each block pads its own content.
      padding: const EdgeInsets.only(bottom: AppSpacing.screenMargin),
      children: [
        // The same micro-label recipe as DATE and TIME on the step before it,
        // rather than a second big heading under the toolbar's own. The
        // reassurance rides along as the header's subtitle.
        const SectionHeader(
          title: 'Summary',
          subtitle:
              'The tailor will confirm your appointment shortly after you book.',
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            AppSpacing.md,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
          ),
          child: NearbyCardList(
            children: [
              _SummaryRow(
                icon: Icons.storefront_rounded,
                label: 'Tailor',
                value: business.name,
              ),
              _SummaryRow(
                icon: Icons.design_services_rounded,
                label: 'Service',
                value: service.name,
                // Only offer the edit when there is a step to go back to.
                onEdit: state.services.length > 1
                    ? () => onEditStep(BookingStep.service)
                    : null,
              ),
              _SummaryRow(
                icon: Icons.event_rounded,
                label: 'Date',
                value: Fmt.fullDate(slot.start),
                onEdit: () => onEditStep(BookingStep.schedule),
              ),
              _SummaryRow(
                icon: Icons.schedule_rounded,
                label: 'Time',
                value: Fmt.timeRange(slot.start, slot.end),
                onEdit: () => onEditStep(BookingStep.schedule),
              ),
              _SummaryRow(
                icon: Icons.currency_rupee_rounded,
                label: 'Price',
                value: service.price == 0
                    ? 'Free'
                    : '${Fmt.priceFrom(service.price)} · final quote at the fitting',
              ),
            ],
          ),
        ),

        // No micro-label over the field: AppTextField already sets a persistent
        // label in exactly that position, and two captions stacked over one
        // input say the same thing twice.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.xxl,
            AppSpacing.screenMargin,
            0,
          ),
          child: AppTextField(
            controller: noteController,
            label: 'Anything the tailor should know?',
            hint: 'e.g. Need it before Diwali',
            helper: 'Optional',
            maxLines: 3,
            maxLength: 200,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            onChanged: onNoteChanged,
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.xl,
            AppSpacing.screenMargin,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: AppSizing.iconSm,
                color: colors.labelSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'You can cancel free of charge up to two hours before the appointment.',
                  style: context.type.caption.copyWith(
                    color: colors.labelSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        onEdit == null ? AppSpacing.lg : AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSizing.iconMd, color: colors.labelSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.type.caption.copyWith(
                    color: colors.labelSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: context.type.subheadEmphasis.copyWith(
                    color: colors.label,
                    // The values stack into a column, and three of the five are
                    // a date, a time range and a price, so the digits are set
                    // to line up.
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              child: Text('Change', semanticsLabel: 'Change $label'),
            ),
        ],
      ),
    );
  }
}

// --- Action bar --------------------------------------------------------------

class _FlowCta extends StatelessWidget {
  const _FlowCta({
    required this.state,
    required this.onNext,
    required this.onSubmit,
  });

  final BookingFlowState state;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isConfirm = state.step == BookingStep.confirm;

    return PrimaryCtaBar(
      label: isConfirm ? 'Confirm booking' : 'Continue',
      icon: isConfirm ? Icons.check_rounded : null,
      isBusy: state.isSubmitting,
      supportingText: _supportingText(state),
      trailingText: isConfirm && state.selectedService != null
          ? (state.selectedService!.price == 0
                ? 'Free'
                : Fmt.priceFrom(state.selectedService!.price))
          : null,
      onPressed: state.canAdvance ? (isConfirm ? onSubmit : onNext) : null,
    );
  }

  /// Names what is still missing, so a disabled Continue is self-explaining.
  static String? _supportingText(BookingFlowState state) {
    return switch (state.step) {
      BookingStep.service =>
        state.selectedService == null
            ? 'Pick a service to continue'
            : state.selectedService!.name,
      // One line for the merged step: it names the choice still outstanding,
      // then reads back the pair once both are made.
      BookingStep.schedule => switch ((
        state.selectedDate,
        state.selectedSlot,
      )) {
        (null, _) => 'Pick a date to continue',
        (_, null) => 'Pick a time to continue',
        (_, final slot?) =>
          '${Fmt.friendlyDate(slot.start)} at ${Fmt.time(slot.start)}',
      },
      // The tray reads the appointment back in full on the last step, opposite
      // the price: the two facts being committed to, side by side, without
      // scrolling back up to the summary card.
      BookingStep.confirm => switch (state.selectedSlot) {
        null => null,
        final slot =>
          '${Fmt.fullDate(slot.start)} · ${Fmt.timeRange(slot.start, slot.end)}',
      },
    };
  }
}

// --- Success -----------------------------------------------------------------

/// Confirmation that the booking landed.
///
/// Design guideline — Feedback > Best practices: "When it makes sense, confirm
/// that a significant action or task has completed. For example, people
/// appreciate getting feedback that confirms a successful transaction."
class _BookingConfirmedScreen extends ConsumerStatefulWidget {
  const _BookingConfirmedScreen({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_BookingConfirmedScreen> createState() =>
      _BookingConfirmedScreenState();
}

class _BookingConfirmedScreenState
    extends ConsumerState<_BookingConfirmedScreen> {
  @override
  void initState() {
    super.initState();
    // The one moment where asking makes obvious sense: the customer is waiting
    // on the tailor to confirm, and a notification is how they find out.
    //
    // Design guideline — Managing notifications: ask when the value is clear,
    // not on first launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushNotificationServiceProvider).ensurePermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // Centred while it fits, scrollable when it does not. A plain
              // Column of Spacers overflowed at large text sizes, and the one
              // screen that says "it worked" is the worst place to lose the
              // bottom of the message.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenMargin,
                    vertical: AppSpacing.xxl,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(
                        0,
                        constraints.maxHeight - AppSpacing.xxl * 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Column(
                              children: [
                                Container(
                                  width: _markSize,
                                  height: _markSize,
                                  decoration: BoxDecoration(
                                    // Monochrome: gold is spoken for by ratings,
                                    // open-now and the pending badge, so success
                                    // is carried by the glyph and the copy. A
                                    // plain surface disc, the same value as the
                                    // card below it.
                                    color: colors.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: _markSize / 2,
                                    color: colors.label,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                Text(
                                  'Appointment requested',
                                  textAlign: TextAlign.center,
                                  style: context.type.title1.copyWith(
                                    color: colors.label,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  '${booking.businessName} will confirm shortly. You will get a notification when they do.',
                                  textAlign: TextAlign.center,
                                  style: context.type.body.copyWith(
                                    color: colors.labelSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          NearbyCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _ConfirmedRow(
                                  label: 'Service',
                                  value: booking.serviceName,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _ConfirmedRow(
                                  label: 'When',
                                  value: Fmt.friendlyDateTime(
                                    booking.startTime,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _ConfirmedRow(
                                  label: 'Where',
                                  value: booking.businessName,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                0,
                AppSpacing.screenMargin,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  // One white pill, the brightest thing on the screen, exactly
                  // as on every other screen with a single next step. Built on
                  // FilledButton directly rather than PrimaryButton because
                  // this label is long enough to need to ellipsize: the shared
                  // widget sets it in a bare Text, which overflows the pill
                  // from about 1.5x text.
                  SizedBox(
                    width: double.infinity,
                    height: AppSizing.primaryButtonHeight,
                    child: FilledButton(
                      onPressed: () => context.go('/bookings'),
                      child: const Text(
                        'View my bookings',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.go('/discover'),
                    child: const Text(
                      'Back to Nearby',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  /// Diameter of the check disc. Imagery rather than scalable content, so it is
  /// a fixed size — the copy beneath it carries the message at any text size.
  static const double _markSize = 84;
}

/// One label/value pair in the confirmation card.
///
/// Label above value rather than beside it, matching the summary rows on the
/// confirm step — and a fixed-width label gutter would either clip or wrap
/// awkwardly once the text scales.
class _ConfirmedRow extends StatelessWidget {
  const _ConfirmedRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.type.caption.copyWith(color: colors.labelSecondary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: context.type.subheadEmphasis.copyWith(
            color: colors.label,
            // "When" is a date and a time; the column lines up on the digits.
            fontFeatures: AppTypography.tabular,
          ),
        ),
      ],
    );
  }
}

// --- Skeletons ---------------------------------------------------------------

/// Placeholder for the service step, which is where the flow always opens.
///
/// Three lines and a trailing disc, matching a service card's name, description
/// and price plus its radio glyph, so the cards land at the height the
/// placeholders already occupied.
class _FlowSkeleton extends StatelessWidget {
  const _FlowSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => NearbyCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton.text(width: 150, fontSize: 17),
                  const SizedBox(height: AppSpacing.sm),
                  Skeleton.text(width: 210, fontSize: 13),
                  const SizedBox(height: AppSpacing.sm),
                  Skeleton.text(width: 110, fontSize: 15),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Skeleton.square(AppSizing.iconLg, radius: AppRadius.pill),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for the time block.
///
/// Shaped from the same column count and cell height as the loaded grid, so the
/// slots appear in place instead of the layout jumping under the customer's
/// thumb. Renders inside the schedule step's own horizontal margin.
class _SlotsSkeleton extends StatelessWidget {
  const _SlotsSkeleton();

  @override
  Widget build(BuildContext context) {
    final height = _slotHeight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stands in for the "n of m times available" count line.
        Skeleton.text(width: 160, fontSize: AppTypography.footnote.fontSize!),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _slotColumns(context),
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: height,
          ),
          itemCount: 12,
          itemBuilder: (_, __) =>
              Skeleton(height: height, radius: AppRadius.md),
        ),
      ],
    );
  }
}
