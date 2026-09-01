import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/illustrations.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../businesses/domain/service_offering.dart';
import '../../businesses/presentation/business_providers.dart';

/// The tailor's price list.
///
/// Services are deactivated rather than deleted, because bookings reference
/// them and history has to keep rendering. The UI says "Stop offering" instead
/// of "Delete" so the behaviour matches the word.
class OwnerServicesScreen extends ConsumerWidget {
  const OwnerServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final business = ref.watch(myBusinessProvider).value;
    final servicesAsync = ref.watch(myServicesProvider);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: Text(
          'Services',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.type.title2.copyWith(color: colors.label),
        ),
        // Measured, not fixed: a screen title set two steps above body size
        // outgrows a hard 64pt bar at the larger accessibility text sizes.
        toolbarHeight: _barHeight(context),
      ),
      floatingActionButton: business == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(context, ref, business.id, null),
              // The screen's one white pill: same fill, label colour and
              // stadium shape as the themed primary button, so the floating
              // action reads as the primary action rather than a Material FAB.
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: const StadiumBorder(),
              // The scheme carries no drop shadows — white on near-black
              // separates itself.
              elevation: 0,
              highlightElevation: 0,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add service'),
            ),
      body: servicesAsync.when(
        loading: () => const LoadingView(label: 'Loading your services'),
        error: (error, _) => ErrorView(
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myServicesProvider),
        ),
        data: (services) {
          if (business == null) return const SizedBox.shrink();

          if (services.isEmpty) {
            return EmptyView(
              illustration: NearbyIllustration.noServices,
              icon: Icons.design_services_outlined,
              title: 'No services yet',
              message:
                  'Add what you do and what you charge. Customers cannot book '
                  'you until you have at least one service.',
              actionLabel: 'Add your first service',
              onAction: () => _openEditor(context, ref, business.id, null),
            );
          }

          final active = services.where((s) => s.isActive).toList();
          final inactive = services.where((s) => !s.isActive).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.sm,
              AppSpacing.screenMargin,
              // Clearance for the floating action button.
              AppSpacing.huge * 2,
            ),
            children: [
              Text(
                active.length == 1
                    ? '1 service customers can book'
                    : '${active.length} services customers can book',
                style: context.type.footnote.copyWith(
                  color: colors.labelSecondary,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              for (final service in active) ...[
                _ServiceTile(
                  service: service,
                  onEdit: () => _openEditor(context, ref, business.id, service),
                  onDeactivate: () => _deactivate(context, ref, service),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (inactive.isNotEmpty) ...[
                // A real section break in the app's own vocabulary — the tiny
                // letterspaced caps micro-label — instead of a hand-rolled
                // heading. Its horizontal inset is dropped because the list
                // already carries the screen margin.
                const SectionHeader(
                  title: 'No longer offered',
                  subtitle:
                      'Kept so your past appointments still make sense. Offer '
                      'one again any time.',
                  padding: EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.md,
                  ),
                ),
                for (final service in inactive) ...[
                  _ServiceTile(
                    service: service,
                    onEdit: () =>
                        _openEditor(context, ref, business.id, service),
                    onReactivate: () => _reactivate(context, ref, service),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  /// One line of the screen title plus breathing room, derived from the text
  /// scale so the bar grows with the type instead of clipping it.
  static double _barHeight(BuildContext context) {
    final titleLine =
        MediaQuery.textScalerOf(context).scale(AppTypography.title2.fontSize!) *
        AppTypography.title2.height!;
    return math.max(kToolbarHeight, titleLine + AppSpacing.xxl + AppSpacing.md);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    String businessId,
    ServiceOffering? existing,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _ServiceEditorSheet(businessId: businessId, existing: existing),
    );
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    ServiceOffering service,
  ) async {
    final confirmed = await AppFeedback.confirmDestructive(
      context,
      title: 'Stop offering ${service.name}?',
      message:
          'Customers will no longer be able to book it. Appointments already '
          'booked are not affected, and you can offer it again any time.',
      confirmLabel: 'Stop offering',
      cancelLabel: 'Keep offering',
    );

    if (!confirmed) return;

    try {
      await ref
          .read(businessRepositoryProvider)
          .deactivateService(
            businessId: service.businessId,
            serviceId: service.id,
          );
      if (context.mounted) {
        AppFeedback.showSuccess(
          context,
          message: '${service.name} is no longer offered.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        AppFeedback.showFailure(context, failure: toAppFailure(error));
      }
    }
  }

  Future<void> _reactivate(
    BuildContext context,
    WidgetRef ref,
    ServiceOffering service,
  ) async {
    try {
      await ref
          .read(businessRepositoryProvider)
          .updateService(service.copyWith(isActive: true));
      if (context.mounted) {
        AppFeedback.showSuccess(
          context,
          message: '${service.name} is available to book again.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        AppFeedback.showFailure(context, failure: toAppFailure(error));
      }
    }
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.onEdit,
    this.onDeactivate,
    this.onReactivate,
  });

  final ServiceOffering service;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback? onReactivate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return NearbyCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: context.type.headline.copyWith(
                    color: service.isActive
                        ? colors.label
                        : colors.labelSecondary,
                  ),
                ),
                if (service.description != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    service.description!,
                    style: context.type.footnote.copyWith(
                      color: colors.labelSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                // Price and duration read as one figure line, so both take
                // tabular numerals and a column of tiles lines up.
                Text(
                  '${service.price == 0 ? 'Free' : Fmt.priceFrom(service.price)} · ${Fmt.duration(service.durationMinutes)}',
                  style: context.type.subheadEmphasis.copyWith(
                    color: colors.labelSecondary,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            ),
          ),
          // Space divides the details from the actions on the dark
          // appearance — dark surfaces are separated by value, never by a
          // hairline. Light keeps the rule, where the white card needs it.
          // Same treatment as a booking card's action tray.
          if (colors.brightness != Brightness.dark)
            const Divider(height: AppSizing.separator),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            // Wrap, not Row: two pill buttons at 2x text scale exceed the card
            // width, and a pill must never truncate its label.
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              // Outlined pills throughout: the screen's one white pill is the
              // Add service action, so nothing inside a card competes with it.
              children: [
                if (onReactivate != null)
                  OutlinedButton(
                    onPressed: onReactivate,
                    child: const Text('Offer again'),
                  ),
                if (onDeactivate != null)
                  OutlinedButton(
                    onPressed: onDeactivate,
                    child: const Text('Stop offering'),
                  ),
                OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Add or edit one service.
class _ServiceEditorSheet extends ConsumerStatefulWidget {
  const _ServiceEditorSheet({required this.businessId, this.existing});

  final String businessId;
  final ServiceOffering? existing;

  @override
  ConsumerState<_ServiceEditorSheet> createState() =>
      _ServiceEditorSheetState();
}

class _ServiceEditorSheetState extends ConsumerState<_ServiceEditorSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.existing == null ? '' : widget.existing!.price.toString(),
  );

  late int _duration =
      widget.existing?.durationMinutes ?? AppConfig.defaultSlotDurationMinutes;

  bool _isSaving = false;
  Map<String, String> _fieldErrors = const {};

  bool get _isEditing => widget.existing != null;

  /// Offered durations. Bounded by what the domain accepts, and kept to
  /// familiar round numbers rather than a free-text field.
  static const List<int> _durationOptions = [15, 30, 45, 60, 90, 120];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final price = int.tryParse(_price.text.trim());
    if (_name.text.trim().isEmpty || price == null) {
      setState(() {
        _fieldErrors = {
          if (_name.text.trim().isEmpty) 'name': 'Give this service a name',
          if (price == null) 'price': 'Enter a price in rupees, or 0 for free',
        };
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _fieldErrors = const {};
    });

    try {
      final repository = ref.read(businessRepositoryProvider);
      final description = _description.text.trim().isEmpty
          ? null
          : _description.text.trim();

      if (_isEditing) {
        await repository.updateService(
          widget.existing!.copyWith(
            name: _name.text,
            price: price,
            durationMinutes: _duration,
            description: description,
          ),
        );
      } else {
        await repository.addService(
          businessId: widget.businessId,
          name: _name.text,
          price: price,
          durationMinutes: _duration,
          description: description,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(
        context,
        message: _isEditing ? 'Service updated.' : 'Service added.',
      );
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
    final colors = context.colors;

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
              _isEditing ? 'Edit service' : 'Add a service',
              style: context.type.title3.copyWith(color: colors.label),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _name,
              label: 'Service name',
              hint: 'e.g. Blouse stitching',
              errorText: _fieldErrors['name'],
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _description,
              label: 'Details',
              hint: 'e.g. Includes one fitting',
              helper: 'Optional',
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _price,
              label: 'Starting price',
              hint: '350',
              helper: 'Shown to customers as "from". Use 0 for free.',
              errorText: _fieldErrors['price'],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              prefixIcon: Icons.currency_rupee_rounded,
            ),
            const SizedBox(height: AppSpacing.xl),

            const FieldGroupLabel('How long does it take?'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final option in _durationOptions)
                  _DurationChip(
                    minutes: option,
                    isSelected: _duration == option,
                    onTap: () => setState(() => _duration = option),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'This is how much of your day one appointment blocks out.',
              style: context.type.caption.copyWith(
                color: colors.labelSecondary,
              ),
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
                  child: SizedBox(
                    height: AppSizing.primaryButtonHeight,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: colors.onPrimary,
                              ),
                            )
                          : Text(_isEditing ? 'Save changes' : 'Add service'),
                    ),
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

class _DurationChip extends StatelessWidget {
  const _DurationChip({
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
            minWidth: 76,
            minHeight: AppSizing.minTouchTarget,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Selection inverts: white cell, black label — the same rule as
            // the primary button and the booking flow's slot cells. Unselected
            // cells are a darker surface value on the raised sheet, with no
            // border in dark; light keeps a hairline because white-on-white
            // has no value separation to lean on.
            color: isSelected ? colors.primary : colors.surface,
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
