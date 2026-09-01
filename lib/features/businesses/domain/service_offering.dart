/// Something a business will do for a price, in a known amount of time.
///
/// Named [ServiceOffering] rather than `Service` because "service" alone is
/// ambiguous in a Flutter codebase, and rather than `TailorService` because the
/// concept is not tailoring-specific — a salon or a mechanic offers these too.
class ServiceOffering {
  const ServiceOffering({
    required this.id,
    required this.businessId,
    required this.name,
    required this.price,
    required this.durationMinutes,
    required this.isActive,
    this.description,
  });

  final String id;
  final String businessId;

  /// What the customer sees: "Shirt stitching", "Blouse stitching".
  final String name;

  /// Starting price in whole rupees. Displayed as "from", because the final
  /// quote for stitched garments depends on the cloth and the fitting.
  final int price;

  /// How long the appointment blocks the business's calendar.
  final int durationMinutes;

  /// An inactive service stays on past bookings but is not offered any more.
  /// Deleting would orphan history, so services are deactivated instead.
  final bool isActive;

  final String? description;

  bool get isValid =>
      name.trim().isNotEmpty &&
      price >= 0 &&
      durationMinutes > 0 &&
      durationMinutes <= 8 * 60;

  ServiceOffering copyWith({
    String? name,
    int? price,
    int? durationMinutes,
    bool? isActive,
    String? description,
  }) => ServiceOffering(
    id: id,
    businessId: businessId,
    name: name ?? this.name,
    price: price ?? this.price,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    isActive: isActive ?? this.isActive,
    description: description ?? this.description,
  );

  @override
  bool operator ==(Object other) => other is ServiceOffering && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
