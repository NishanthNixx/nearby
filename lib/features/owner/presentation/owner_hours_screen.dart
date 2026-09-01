import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/primary_cta.dart';
import '../../../core/widgets/section_header.dart';
import '../../businesses/domain/opening_hours.dart';
import '../../businesses/presentation/business_providers.dart';

/// When the shop is open, and how long one appointment runs.
///
/// Everything on this screen feeds slot generation, so the copy connects each
/// control to its consequence — a tailor changing their closing time should be
/// able to see why it matters.
class OwnerHoursScreen extends ConsumerStatefulWidget {
  const OwnerHoursScreen({super.key});

  @override
  ConsumerState<OwnerHoursScreen> createState() => _OwnerHoursScreenState();
}

class _OwnerHoursScreenState extends ConsumerState<OwnerHoursScreen> {
  /// Local working copy. Edits are staged here and only written when the tailor
  /// saves, so a mis-tap on a switch is not immediately live to customers.
  OpeningHours? _draft;
  bool _isSaving = false;

  static const List<String> _dayNames = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  bool get _hasChanges {
    final saved = ref.read(myBusinessProvider).value?.openingHours;
    final draft = _draft;
    if (saved == null || draft == null) return false;

    if (saved.slotDurationMinutes != draft.slotDurationMinutes) return true;
    for (var weekday = 1; weekday <= 7; weekday++) {
      if (saved.forWeekday(weekday) != draft.forWeekday(weekday)) return true;
    }
    return false;
  }

  Future<void> _save(String businessId) async {
    final draft = _draft;
    if (draft == null) return;

    setState(() => _isSaving = true);

    try {
      await ref
          .read(businessRepositoryProvider)
          .updateOpeningHours(businessId, draft);

      if (!mounted) return;
      setState(() => _isSaving = false);
      AppFeedback.showSuccess(context, message: 'Opening hours saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppFeedback.showFailure(context, failure: toAppFailure(error));
    }
  }

  Future<void> _pickTime({
    required int weekday,
    required bool isOpening,
  }) async {
    final draft = _draft;
    if (draft == null) return;

    final day = draft.forWeekday(weekday);
    final current = isOpening ? day.opensAt : day.closesAt;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: isOpening
          ? '${_dayNames[weekday]} opening time'
          : '${_dayNames[weekday]} closing time',
    );

    if (picked == null) return;

    final value = TimeOfDayValue(hour: picked.hour, minute: picked.minute);
    final updated = isOpening
        ? day.copyWith(opensAt: value)
        : day.copyWith(closesAt: value);

    // Rejected here rather than at save time, so the tailor finds out while
    // they are still looking at the field they changed.
    if (!updated.isValid) {
      if (mounted) {
        AppFeedback.showInfo(
          context,
          message: 'Closing time has to be after opening time.',
        );
      }
      return;
    }

    _updateDay(weekday, updated);
  }

  void _updateDay(int weekday, DayHours hours) {
    final draft = _draft;
    if (draft == null) return;

    setState(() {
      _draft = draft.copyWith(byWeekday: {...draft.byWeekday, weekday: hours});
    });
  }

  /// Copies Monday's hours across every open day — the request that comes up
  /// most, and tedious without it.
  void _applyMondayToAll() {
    final draft = _draft;
    if (draft == null) return;

    final monday = draft.forWeekday(DateTime.monday);

    setState(() {
      _draft = draft.copyWith(
        byWeekday: {
          for (var weekday = 1; weekday <= 7; weekday++)
            weekday: draft.forWeekday(weekday).isOpen
                ? monday.copyWith(isOpen: true)
                : draft.forWeekday(weekday),
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final businessAsync = ref.watch(myBusinessProvider);

    return businessAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, _) => Scaffold(
        body: ErrorView(
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myBusinessProvider),
        ),
      ),
      data: (business) {
        if (business == null) return const Scaffold(body: SizedBox.shrink());

        // Seeded once from the saved value, then owned locally.
        _draft ??= business.openingHours;
        final draft = _draft!;

        return Scaffold(
          backgroundColor: colors.bgBase,
          appBar: AppBar(
            title: Text(
              'Hours',
              style: context.type.title2.copyWith(color: colors.label),
            ),
            toolbarHeight: 64,
          ),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    AppSpacing.sm,
                    AppSpacing.screenMargin,
                    0,
                  ),
                  child: Text(
                    'Customers can only book inside these hours.',
                    style: context.type.subhead.copyWith(
                      color: colors.labelSecondary,
                    ),
                  ),
                ),

                SectionHeader(
                  title: 'Your week',
                  actionLabel: 'Copy Monday',
                  onAction: _applyMondayToAll,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenMargin,
                  ),
                  child: NearbyCardList(
                    children: [
                      for (var weekday = 1; weekday <= 7; weekday++)
                        _DayRow(
                          name: _dayNames[weekday],
                          hours: draft.forWeekday(weekday),
                          onToggle: (isOpen) => _updateDay(
                            weekday,
                            draft.forWeekday(weekday).copyWith(isOpen: isOpen),
                          ),
                          onEditOpening: () =>
                              _pickTime(weekday: weekday, isOpening: true),
                          onEditClosing: () =>
                              _pickTime(weekday: weekday, isOpening: false),
                        ),
                    ],
                  ),
                ),

                const SectionHeader(
                  title: 'Appointment length',
                  subtitle: 'How far apart your appointment slots are',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenMargin,
                  ),
                  child: NearbyCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final minutes in const [15, 30, 45, 60])
                              _SlotDurationChip(
                                minutes: minutes,
                                isSelected:
                                    draft.slotDurationMinutes == minutes,
                                onTap: () => setState(() {
                                  _draft = draft.copyWith(
                                    slotDurationMinutes: minutes,
                                  );
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _slotExplanation(draft),
                          style: context.type.footnote.copyWith(
                            color: colors.labelSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                if (!draft.isValid)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenMargin,
                    ),
                    child: InlineNotice(
                      message:
                          'At least one day has to be open, and every open day '
                          'needs a closing time after its opening time.',
                    ),
                  ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
          bottomNavigationBar: _hasChanges
              ? PrimaryCtaBar(
                  label: 'Save hours',
                  isBusy: _isSaving,
                  supportingText: 'Unsaved changes',
                  secondaryLabel: 'Discard',
                  onSecondaryPressed: () => setState(() {
                    _draft = business.openingHours;
                  }),
                  onPressed: draft.isValid ? () => _save(business.id) : null,
                )
              : null,
        );
      },
    );
  }

  /// Connects the abstract setting to what the tailor's day will look like.
  static String _slotExplanation(OpeningHours hours) {
    final openDay = hours.byWeekday.entries
        .where((e) => e.value.isOpen)
        .firstOrNull;

    if (openDay == null) {
      return 'Set at least one open day to see how many appointments this allows.';
    }

    final day = openDay.value;
    final count = day.openMinutes ~/ hours.slotDurationMinutes;

    return 'On a day from ${day.opensAt} to ${day.closesAt}, that is up to '
        '$count appointment slots. A service that takes longer than one slot '
        'simply blocks more than one.';
  }
}

/// One weekday: an on/off switch and, when open, its two times.
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.name,
    required this.hours,
    required this.onToggle,
    required this.onEditOpening,
    required this.onEditClosing,
  });

  final String name;
  final DayHours hours;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditOpening;
  final VoidCallback onEditClosing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: context.type.body.copyWith(color: colors.label),
                ),
              ),
              // The switch carries a text label beside it, so "open" is not
              // conveyed by the switch position alone. Monochrome on purpose:
              // gold is reserved for the live open-now concept, and this is a
              // schedule setting — white for open, secondary for closed.
              Text(
                hours.isOpen ? 'Open' : 'Closed',
                style: context.type.footnote.copyWith(
                  color: hours.isOpen ? colors.label : colors.labelSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Labelled explicitly: without this a screen reader announces
              // seven identical unlabelled switches.
              Semantics(
                label: '$name open',
                toggled: hours.isOpen,
                excludeSemantics: true,
                child: Switch(value: hours.isOpen, onChanged: onToggle),
              ),
            ],
          ),
          if (hours.isOpen) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'Opens',
                    value: Fmt.time(hours.opensAt.onDate(today)),
                    onTap: onEditOpening,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _TimeButton(
                    label: 'Closes',
                    value: Fmt.time(hours.closesAt.onDate(today)),
                    onTap: onEditClosing,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: '$label at $value. Change',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSizing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            // A filled tile, not an outlined one: surfaceRaised is the
            // layer-above-a-surface value, so the button lifts off the card it
            // sits in on value alone. Dark carries no border at all; light
            // keeps a hairline, having no value separation to lean on.
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: colors.brightness == Brightness.dark
                ? null
                : Border.all(color: colors.separator),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: context.type.caption.copyWith(
                        color: colors.labelSecondary,
                      ),
                    ),
                    Text(
                      value,
                      style: context.type.subheadEmphasis.copyWith(
                        color: colors.label,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                size: AppSizing.iconSm,
                color: colors.labelTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotDurationChip extends StatelessWidget {
  const _SlotDurationChip({
    required this.minutes,
    required this.isSelected,
    required this.onTap,
  });

  final int minutes;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: Fmt.duration(minutes),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 72,
            minHeight: AppSizing.minTouchTarget,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Selection inverts: white chip, black label — the same rule as
            // the primary button and the booking flow's slot cells. Unselected
            // chips take the raised value of the card they sit in, borderless
            // in dark.
            color: isSelected ? colors.primary : colors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: isSelected || colors.brightness == Brightness.dark
                ? null
                : Border.all(color: colors.separator),
          ),
          child: Text(
            Fmt.duration(minutes),
            style: context.type.subheadEmphasis.copyWith(
              color: isSelected ? colors.onPrimary : colors.label,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ),
      ),
    );
  }
}
