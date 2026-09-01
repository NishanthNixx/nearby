import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../businesses/domain/business.dart';
import '../../businesses/domain/service_offering.dart';
import '../domain/availability_calculator.dart';
import '../domain/booking.dart';

/// The three steps of booking, in the one order they happen.
///
/// Date and time live together on one schedule step, the way the reference
/// lays out its booking screen: picking a day and picking a slot are one
/// decision, and splitting them made the flow feel longer than it is.
///
/// Design guideline — Modality > Best practices: "If a modal task must contain
/// subviews, provide a single path through the hierarchy and avoid including
/// buttons that people might mistake for the button that dismisses the modal
/// view." So this is a linear sequence, not a tree.
enum BookingStep {
  service,
  schedule,
  confirm;

  String get title => switch (this) {
    BookingStep.service => 'Choose a service',
    BookingStep.schedule => 'Choose date and time',
    BookingStep.confirm => 'Confirm booking',
  };
}

class BookingFlowState {
  const BookingFlowState({
    required this.step,
    this.business,
    this.services = const [],
    this.selectedService,
    this.selectedDate,
    this.selectedSlot,
    this.note = '',
    this.slots,
    this.isLoadingSlots = false,
    this.isSubmitting = false,
    this.failure,
    this.createdBooking,
    this.isLoadingBusiness = true,
    this.skipsServiceStep = false,
  });

  final BookingStep step;

  final Business? business;
  final List<ServiceOffering> services;

  final ServiceOffering? selectedService;
  final DateTime? selectedDate;
  final TimeSlot? selectedSlot;
  final String note;

  /// Null until a date is chosen and its slots have loaded.
  final List<TimeSlot>? slots;

  final bool isLoadingSlots;
  final bool isSubmitting;
  final bool isLoadingBusiness;

  final AppFailure? failure;

  /// Set once the booking is created; the screen switches to its success state.
  final Booking? createdBooking;

  /// Whether the service step was genuinely skipped.
  ///
  /// Derived from whether a preselected service actually *resolved*, not from
  /// whether one was requested. A stale or wrong service id leaves the customer
  /// on the service step, and a progress indicator keyed off the request rather
  /// than the outcome would then count a step that is plainly on screen.
  final bool skipsServiceStep;

  /// The steps this flow presents, in order. The progress indicator and the
  /// step numbering both read from this, so they cannot disagree.
  List<BookingStep> get visibleSteps => skipsServiceStep
      ? const [BookingStep.schedule, BookingStep.confirm]
      : BookingStep.values;

  /// One-based position of the current step among [visibleSteps].
  int get stepNumber {
    final index = visibleSteps.indexOf(step);
    // A step outside the visible set would mean the two had drifted apart;
    // clamping keeps the label sane rather than showing "Step 0".
    return index < 0 ? 1 : index + 1;
  }

  int get stepCount => visibleSteps.length;

  bool get isComplete => createdBooking != null;

  /// Dates worth offering: the business trades on them and they are inside the
  /// booking horizon.
  List<DateTime> get selectableDates {
    final hours = business?.openingHours;
    if (hours == null) return const [];
    return AvailabilityCalculator.selectableDates(
      from: DateTime.now(),
      openingHours: hours,
      horizonDays: AppConfig.bookingHorizonDays,
    );
  }

  List<TimeSlot> get availableSlots =>
      slots?.where((s) => s.isAvailable).toList(growable: false) ?? const [];

  /// Whether the current step's requirement is met.
  bool get canAdvance => switch (step) {
    BookingStep.service => selectedService != null,
    // A slot implies a date, so the merged schedule step needs only the slot.
    BookingStep.schedule => selectedSlot != null,
    BookingStep.confirm => !isSubmitting,
  };

  BookingFlowState copyWith({
    BookingStep? step,
    Business? business,
    List<ServiceOffering>? services,
    ServiceOffering? selectedService,
    DateTime? selectedDate,
    TimeSlot? selectedSlot,
    bool clearSlot = false,
    String? note,
    List<TimeSlot>? slots,
    bool clearSlots = false,
    bool? isLoadingSlots,
    bool? isSubmitting,
    bool? isLoadingBusiness,
    AppFailure? failure,
    bool clearFailure = false,
    Booking? createdBooking,
    bool? skipsServiceStep,
  }) => BookingFlowState(
    step: step ?? this.step,
    business: business ?? this.business,
    services: services ?? this.services,
    selectedService: selectedService ?? this.selectedService,
    selectedDate: selectedDate ?? this.selectedDate,
    selectedSlot: clearSlot ? null : (selectedSlot ?? this.selectedSlot),
    note: note ?? this.note,
    slots: clearSlots ? null : (slots ?? this.slots),
    isLoadingSlots: isLoadingSlots ?? this.isLoadingSlots,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isLoadingBusiness: isLoadingBusiness ?? this.isLoadingBusiness,
    failure: clearFailure ? null : (failure ?? this.failure),
    createdBooking: createdBooking ?? this.createdBooking,
    skipsServiceStep: skipsServiceStep ?? this.skipsServiceStep,
  );
}

/// Arguments identifying which flow this is.
class BookingFlowArgs {
  const BookingFlowArgs({required this.businessId, this.serviceId});

  final String businessId;

  /// Set when the customer tapped a specific service on the profile, which
  /// skips the first step.
  final String? serviceId;

  @override
  bool operator ==(Object other) =>
      other is BookingFlowArgs &&
      other.businessId == businessId &&
      other.serviceId == serviceId;

  @override
  int get hashCode => Object.hash(businessId, serviceId);
}

class BookingFlowController
    extends FamilyNotifier<BookingFlowState, BookingFlowArgs> {
  @override
  BookingFlowState build(BookingFlowArgs arg) {
    Future.microtask(_initialise);
    return const BookingFlowState(step: BookingStep.service);
  }

  Future<void> _initialise() async {
    try {
      final repository = ref.read(businessRepositoryProvider);

      final business = await repository.getBusiness(arg.businessId);
      if (business == null) {
        state = state.copyWith(
          isLoadingBusiness: false,
          failure: const NotFoundFailure(what: 'tailor'),
        );
        return;
      }

      final services = await repository.getServices(arg.businessId);

      // A service arriving from the profile skips step one, landing the
      // customer straight on the date — one fewer tap for the common path.
      final preselected = arg.serviceId == null
          ? null
          : services.where((s) => s.id == arg.serviceId).firstOrNull;

      state = state.copyWith(
        business: business,
        services: services,
        isLoadingBusiness: false,
        selectedService: preselected,
        step: preselected == null ? BookingStep.service : BookingStep.schedule,
        // Keyed off the resolved service, so a service id that no longer exists
        // falls back to showing the step rather than silently miscounting it.
        skipsServiceStep: preselected != null,
      );

      if (preselected != null) {
        final firstDate = state.selectableDates.firstOrNull;
        if (firstDate != null) await selectDate(firstDate);
      }
    } catch (error) {
      state = state.copyWith(
        isLoadingBusiness: false,
        failure: toAppFailure(error),
      );
    }
  }

  void selectService(ServiceOffering service) {
    // Changing the service changes how long the appointment runs, so any
    // previously generated slots are stale.
    state = state.copyWith(
      selectedService: service,
      clearSlot: true,
      clearSlots: true,
      clearFailure: true,
    );
  }

  Future<void> selectDate(DateTime date) async {
    state = state.copyWith(
      selectedDate: date,
      clearSlot: true,
      clearSlots: true,
      clearFailure: true,
    );
    await _loadSlots();
  }

  void selectSlot(TimeSlot slot) {
    if (!slot.isAvailable) return;
    state = state.copyWith(selectedSlot: slot, clearFailure: true);
  }

  void setNote(String note) => state = state.copyWith(note: note);

  void goToStep(BookingStep step) =>
      state = state.copyWith(step: step, clearFailure: true);

  void next() {
    if (!state.canAdvance) return;
    final steps = state.visibleSteps;
    final index = steps.indexOf(state.step);
    if (index < 0 || index + 1 >= steps.length) return;

    final nextStep = steps[index + 1];
    state = state.copyWith(step: nextStep, clearFailure: true);

    // Landing on the schedule with nothing chosen would show an empty time
    // grid, so the first open day is preselected — the same head start the
    // preselected-service entry path gives. Fire-and-forget: the step change
    // must not wait on the slots request.
    if (nextStep == BookingStep.schedule) {
      if (state.selectedDate == null) {
        final firstDate = state.selectableDates.firstOrNull;
        if (firstDate != null) unawaited(selectDate(firstDate));
      } else if (state.slots == null && !state.isLoadingSlots) {
        // A kept date whose slots were invalidated (the service changed, so
        // durations differ) reloads rather than presenting a stale blank.
        unawaited(_loadSlots());
      }
    }
  }

  /// Steps back, returning false when there is nowhere left to go — which the
  /// screen reads as "close the flow".
  ///
  /// Walks [BookingFlowState.visibleSteps], so a skipped service step is never
  /// landed on: going back from the schedule then leaves the flow rather than
  /// showing a step the customer never saw.
  bool back() {
    final steps = state.visibleSteps;
    final index = steps.indexOf(state.step);
    if (index <= 0) return false;

    state = state.copyWith(step: steps[index - 1], clearFailure: true);
    return true;
  }

  Future<void> _loadSlots() async {
    final business = state.business;
    final service = state.selectedService;
    final date = state.selectedDate;

    if (business == null || service == null || date == null) return;

    state = state.copyWith(isLoadingSlots: true, clearFailure: true);

    try {
      final existing = await ref
          .read(bookingRepositoryProvider)
          .getBookingsForDay(businessId: business.id, date: date);

      final slots = AvailabilityCalculator.slotsForDay(
        date: date,
        openingHours: business.openingHours,
        serviceDurationMinutes: service.durationMinutes,
        existingBookings: existing,
        now: DateTime.now(),
        minimumLeadTime: AppConfig.minimumBookingLeadTime,
      );

      state = state.copyWith(slots: slots, isLoadingSlots: false);
    } catch (error) {
      state = state.copyWith(
        isLoadingSlots: false,
        failure: toAppFailure(error),
      );
    }
  }

  /// Submits the booking.
  ///
  /// The repository's write is the authority on whether the slot is free. When
  /// it reports the slot gone, the flow returns to the schedule step with a
  /// fresh list rather than leaving a stale one on screen.
  Future<bool> submit() async {
    final business = state.business;
    final service = state.selectedService;
    final slot = state.selectedSlot;

    if (business == null || service == null || slot == null) return false;

    state = state.copyWith(isSubmitting: true, clearFailure: true);

    try {
      final booking = await ref
          .read(bookingRepositoryProvider)
          .createBooking(
            BookingRequest(
              businessId: business.id,
              serviceId: service.id,
              startTime: slot.start,
              note: state.note,
            ),
          );

      state = state.copyWith(isSubmitting: false, createdBooking: booking);
      return true;
    } on SlotUnavailableFailure catch (failure) {
      state = state.copyWith(
        isSubmitting: false,
        step: BookingStep.schedule,
        clearSlot: true,
      );
      await _loadSlots();

      // The failure is applied *after* the reload, not before: _loadSlots
      // clears the failure so a step never opens under a stale banner, which
      // would otherwise swallow the one message the customer needs — that the
      // time they picked has just gone. A failure the reload raised itself is
      // more urgent still, so it wins.
      if (state.failure == null) {
        state = state.copyWith(failure: failure);
      }
      return false;
    } catch (error) {
      state = state.copyWith(isSubmitting: false, failure: toAppFailure(error));
      return false;
    }
  }

  /// Re-checks availability for the chosen date.
  Future<void> refreshSlots() => _loadSlots();
}

final bookingFlowControllerProvider =
    NotifierProvider.family<
      BookingFlowController,
      BookingFlowState,
      BookingFlowArgs
    >(BookingFlowController.new);
