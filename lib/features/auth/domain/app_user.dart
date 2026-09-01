/// What a signed-in person is here to do.
///
/// A single account has exactly one role. Keeping the two experiences separate
/// avoids a mode switch in the UI, which is the wrong kind of complexity for a
/// tailor with limited technical experience.
enum UserRole {
  /// Discovers businesses and books appointments.
  customer,

  /// Owns a business listing and manages its appointments.
  businessOwner;

  bool get isCustomer => this == UserRole.customer;
  bool get isBusinessOwner => this == UserRole.businessOwner;
}

/// The signed-in user, as the app understands them.
///
/// Contains no credential material and no backend types — this is what the UI
/// and controllers see.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.displayName,
    this.phone,
    this.photoUrl,
    this.businessId,
  });

  /// Stable identifier. Firebase Auth UID today; a primary key later.
  final String id;

  final String email;
  final UserRole role;
  final DateTime createdAt;

  final String? displayName;
  final String? phone;
  final String? photoUrl;

  /// The business this owner manages. Null for customers, and null for an
  /// owner who has not created their listing yet — which is what the
  /// onboarding flow keys off.
  final String? businessId;

  /// Whether a business owner still needs to create their listing.
  bool get needsBusinessSetup => role.isBusinessOwner && businessId == null;

  /// Best available name for greeting and review attribution.
  String get name {
    final trimmed = displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final localPart = email.split('@').first;
    return localPart.isEmpty ? 'there' : localPart;
  }

  /// One or two letters for an avatar placeholder.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  AppUser copyWith({
    String? displayName,
    String? phone,
    String? photoUrl,
    String? businessId,
    bool clearBusinessId = false,
  }) {
    return AppUser(
      id: id,
      email: email,
      role: role,
      createdAt: createdAt,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      businessId: clearBusinessId ? null : (businessId ?? this.businessId),
    );
  }

  @override
  bool operator ==(Object other) => other is AppUser && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
