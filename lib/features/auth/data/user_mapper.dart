import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firebase_error_mapper.dart';
import '../domain/app_user.dart';

/// Converts between Firestore user documents and [AppUser].
///
/// All Firestore-specific types stop here. A future REST implementation writes
/// an equivalent mapper against JSON and nothing above the data layer changes.
abstract final class UserMapper {
  static const String _fieldEmail = 'email';
  static const String _fieldRole = 'role';
  static const String _fieldDisplayName = 'displayName';
  static const String _fieldPhone = 'phone';
  static const String _fieldPhotoUrl = 'photoUrl';
  static const String _fieldBusinessId = 'businessId';
  static const String _fieldCreatedAt = 'createdAt';

  static AppUser fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      id: doc.id,
      email: (data[_fieldEmail] as String?) ?? '',
      role: roleFromString(data[_fieldRole] as String?),
      createdAt: FirestoreTime.toDateTimeOr(
        data[_fieldCreatedAt],
        DateTime.now(),
      ),
      displayName: data[_fieldDisplayName] as String?,
      phone: data[_fieldPhone] as String?,
      photoUrl: data[_fieldPhotoUrl] as String?,
      businessId: data[_fieldBusinessId] as String?,
    );
  }

  /// The document written when an account is created.
  ///
  /// `role` is written once here and never included in an update payload — the
  /// security rules reject any change to it, so an account cannot escalate
  /// itself from customer to business owner.
  static Map<String, Object?> toCreatePayload(AppUser user) => {
    _fieldEmail: user.email,
    _fieldRole: user.role.name,
    _fieldDisplayName: user.displayName,
    _fieldPhone: user.phone,
    _fieldPhotoUrl: user.photoUrl,
    _fieldBusinessId: user.businessId,
    _fieldCreatedAt: FieldValue.serverTimestamp(),
  };

  /// Only the fields a user may change about themselves.
  static Map<String, Object?> toProfileUpdatePayload({
    String? displayName,
    String? phone,
    String? photoUrl,
  }) {
    return {
      if (displayName != null) _fieldDisplayName: displayName,
      if (phone != null) _fieldPhone: phone,
      if (photoUrl != null) _fieldPhotoUrl: photoUrl,
    };
  }

  static Map<String, Object?> toBusinessLinkPayload(String businessId) => {
    _fieldBusinessId: businessId,
  };

  static UserRole roleFromString(String? value) => switch (value) {
    'businessOwner' => UserRole.businessOwner,
    _ => UserRole.customer,
  };
}
